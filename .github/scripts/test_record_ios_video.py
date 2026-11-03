"""Capture a native frame before releasing the test."""

import asyncio
import json
from pathlib import Path
import subprocess
import sys
from uuid import UUID

import pytest

from fake_video_process import FakeVideoProcess
import record_ios_video


class TestRecordIosVideo:
    def test_when_recording_is_finalized_then_its_capture_interval_is_reported(
        self: "TestRecordIosVideo",
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: Path,
    ) -> None:
        async def exercise() -> None:
            # given
            scenario = self.Scenario(directory=tmp_path, monkeypatch=monkeypatch)
            scenario.process.stderr.feed_data(b"Recording started\n")

            # when
            await scenario.sut(
                armed_path=scenario.armed_path,
                duration=0.001,
                output_path=tmp_path / "collapse.mp4",
                simulator_id=UUID("b6bcfc3d-3add-42c8-bb29-33ff8fe7e0b0"),
            )

            # then
            receipt = json.loads((tmp_path / "collapse.recording.json").read_text())
            assert receipt["first_frame_reported"] < receipt["stop_requested"] <= receipt["finalized"]
            assert receipt["clock_implementation"]

        asyncio.run(exercise())

    def test_when_invoked_without_capture_arguments_then_usage_is_reported(
        self: "TestRecordIosVideo",
    ) -> None:
        # when
        result = subprocess.run(
            [sys.executable, str(Path(record_ios_video.__file__))],
            capture_output=True,
            check=False,
            text=True,
        )

        # then
        assert result.returncode == 2
        assert "Usage: record_ios_video.py" in result.stderr

    def test_given_a_waiting_recorder_when_first_frame_is_reported_then_the_test_is_armed(
        self: "TestRecordIosVideo",
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: Path,
    ) -> None:
        async def exercise() -> None:
            # given
            scenario = self.Scenario(directory=tmp_path, monkeypatch=monkeypatch)

            # when
            recording = asyncio.create_task(scenario.sut(
                armed_path=scenario.armed_path,
                duration=0.001,
                output_path=tmp_path / "collapse.mp4",
                simulator_id=UUID("b6bcfc3d-3add-42c8-bb29-33ff8fe7e0b0"),
            ))
            try:
                await asyncio.wait_for(scenario.process.stderr.read_started.wait(), timeout=1)
                scenario.process.stderr.read_started.clear()
                scenario.process.stderr.feed_data(b"Waiting for simulator frames\n")
                await asyncio.wait_for(scenario.process.stderr.read_started.wait(), timeout=1)

                # then
                assert not scenario.armed_path.exists()
                scenario.process.stderr.feed_data(b"Recording started\n")
                await asyncio.wait_for(recording, timeout=1)
                assert scenario.armed_path.exists()
            finally:
                recording.cancel()
                await asyncio.gather(recording, return_exceptions=True)

        asyncio.run(exercise())

    class Scenario:
        def __init__(
            self: "TestRecordIosVideo.Scenario",
            directory: Path,
            monkeypatch: pytest.MonkeyPatch,
        ) -> None:
            self.armed_path = directory / "test.armed"
            self.process = FakeVideoProcess()
            self.sut = record_ios_video.record_video
            monkeypatch.setattr(asyncio, "create_subprocess_exec", self.process.create_subprocess_exec)
