"""Bounded simulator video, independent of the app's main-thread observer."""

import asyncio
import json
from pathlib import Path
import signal
import sys
import time
from typing import TypedDict
from uuid import UUID


class VideoCaptureClock(TypedDict):
    clock_implementation: str
    finalized: float
    first_frame_reported: float
    stop_requested: float


async def record_video(
    armed_path: Path,
    duration: float,
    output_path: Path,
    simulator_id: UUID,
) -> None:
    process = await asyncio.create_subprocess_exec(
        "xcrun", "simctl", "io", str(simulator_id), "recordVideo", "--codec=h264", str(output_path),
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        if process.stderr is None:
            raise RuntimeError("The video recorder has no readiness stream")
        loop = asyncio.get_running_loop()
        deadline = loop.time() + 120
        while True:
            line = await asyncio.wait_for(process.stderr.readline(), timeout=max(0, deadline - loop.time()))
            if not line:
                raise RuntimeError("The video recorder ended before processing its first frame")
            print(line.decode(errors="replace"), end="", file=sys.stderr, flush=True)
            if line.strip() == b"Recording started":
                break
        first_frame_reported = time.monotonic()
        armed_path.touch(exist_ok=False)
        try:
            status = await asyncio.wait_for(process.wait(), timeout=duration)
        except asyncio.TimeoutError:
            stop_requested = time.monotonic()
            process.send_signal(signal.SIGINT)
            status = await asyncio.wait_for(process.wait(), timeout=30)
        else:
            raise RuntimeError(f"The video recorder ended before the capture deadline: {status}")
        if status != 0:
            raise RuntimeError(f"The video recorder failed to finalize: {status}")
        receipt: VideoCaptureClock = {
            "clock_implementation": time.get_clock_info("monotonic").implementation,
            "finalized": time.monotonic(),
            "first_frame_reported": first_frame_reported,
            "stop_requested": stop_requested,
        }
        output_path.with_suffix(".recording.json").write_text(json.dumps(receipt), encoding="utf-8")
    finally:
        if process.returncode is None:
            process.send_signal(signal.SIGINT)
            try:
                await asyncio.wait_for(process.wait(), timeout=30)
            except asyncio.TimeoutError:
                process.kill()
                await asyncio.wait_for(process.wait(), timeout=10)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: record_ios_video.py ARMED_PATH OUTPUT_PATH SIMULATOR_UUID", file=sys.stderr)
        raise SystemExit(2)
    asyncio.run(record_video(
        armed_path=Path(sys.argv[1]),
        duration=10,
        output_path=Path(sys.argv[2]),
        simulator_id=UUID(sys.argv[3]),
    ))
