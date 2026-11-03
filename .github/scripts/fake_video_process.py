"""A native recorder controlled by its test."""

import asyncio
import signal


class FakeVideoProcess:
    def __init__(self: "FakeVideoProcess") -> None:
        self.returncode: int | None = None
        self.stderr = FakeVideoStreamReader()
        self._stopped = asyncio.Event()

    async def create_subprocess_exec(
        self: "FakeVideoProcess",
        program: str,
        *arguments: str,
        **options: object,
    ) -> "FakeVideoProcess":
        return self

    def send_signal(
        self: "FakeVideoProcess",
        received_signal: signal.Signals,
    ) -> None:
        self.returncode = 0
        self.stderr.feed_eof()
        self._stopped.set()

    async def wait(self: "FakeVideoProcess") -> int:
        await self._stopped.wait()
        return 0


class FakeVideoStreamReader(asyncio.StreamReader):
    def __init__(self: "FakeVideoStreamReader") -> None:
        super().__init__()
        self.read_started = asyncio.Event()

    async def readline(self: "FakeVideoStreamReader") -> bytes:
        self.read_started.set()
        return await super().readline()
