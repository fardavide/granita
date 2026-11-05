"""Snapshot destinations must retain the runtime that recorded their baselines."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess
from textwrap import dedent


class TestSnapshotDestination:
    def test_given_same_phone_in_newer_runtime_when_planning_snapshots_then_uses_baseline_runtime(
        self: "TestSnapshotDestination",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(
            devices=dedent("""\
                == Devices ==
                -- iOS 27.0 --
                    iPhone 18 Pro (11111111-1111-1111-1111-111111111111) (Shutdown)
                -- iOS 27.2 --
                    iPhone 18 Pro (22222222-2222-2222-2222-222222222222) (Shutdown)
                """),
            root=tmp_path,
        )

        # when
        result = subprocess.run(
            ["make", "-n", "snapshots-ios"],
            capture_output=True,
            check=False,
            cwd=scenario.source,
            env=scenario.environment,
            text=True,
        )

        # then
        assert result.returncode == 0, result.stdout + result.stderr
        arguments = shlex.split(result.stdout)
        destination = dict(part.split("=", 1) for part in arguments[arguments.index("-destination") + 1].split(","))
        assert destination["platform"] == "iOS Simulator"
        if "id" in destination:
            assert destination["id"] == "11111111-1111-1111-1111-111111111111", result.stdout
        else:
            assert destination["name"] == "iPhone 18 Pro", result.stdout
            assert destination["OS"] == "27.0", result.stdout

    class Scenario:
        def __init__(
            self: "TestSnapshotDestination.Scenario",
            devices: str,
            root: Path,
        ) -> None:
            self.source = Path(__file__).resolve().parents[2]
            inventory = root / "devices.txt"
            inventory.write_text(devices)
            tools = root / "tools"
            tools.mkdir()
            shutil.copyfile(self.source / ".github/scripts/fake_simulator_discovery.py", tools / "xcrun")
            (tools / "xcrun").chmod(0o755)
            self.environment = dict(os.environ)
            self.environment.update({
                "FAKE_SIMULATOR_DEVICE_LIST": str(inventory),
                "PATH": str(tools) + os.pathsep + os.environ.get("PATH", ""),
            })
