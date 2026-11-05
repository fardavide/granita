"""Coverage collection must retain a simulator explicitly chosen by its caller."""

import os
from pathlib import Path
import shlex
import shutil
import subprocess
from textwrap import dedent


class TestCoverageSimulator:
    def test_given_selected_simulator_when_collecting_then_boot_and_tests_use_it_without_rediscovery(
        self: "TestCoverageSimulator",
        tmp_path: Path,
    ) -> None:
        # given
        selected_uuid = "22222222-2222-2222-2222-222222222222"
        scenario = self.Scenario(root=tmp_path, selected_uuid=selected_uuid)

        # when
        result = subprocess.run(
            ["bash", ".github/scripts/collect-coverage.sh", "ios"],
            capture_output=True,
            check=False,
            cwd=tmp_path,
            env=scenario.environment,
            text=True,
        )

        # then
        assert result.returncode == 92, result.stdout + result.stderr
        calls = [shlex.split(line) for line in scenario.receipt.read_text().splitlines()]
        test_calls = [call for call in calls if call[:2] == ["xcodebuild", "test"]]
        assert len(test_calls) == 1, calls
        arguments = test_calls[0]
        assert arguments[arguments.index("-destination") + 1] == (
            f"platform=iOS Simulator,id={selected_uuid}"
        ), calls
        assert [call for call in calls if call[0] == "xcrun"] == [
            ["xcrun", "simctl", "boot", selected_uuid],
        ]

    class Scenario:
        def __init__(
            self: "TestCoverageSimulator.Scenario",
            root: Path,
            selected_uuid: str,
        ) -> None:
            source = Path(__file__).resolve().parents[2]
            scripts = root / ".github/scripts"
            scripts.mkdir(parents=True)
            for name in ("collect-coverage.sh", "ios-simulator.sh", "source_digest.py"):
                shutil.copyfile(source / ".github/scripts" / name, scripts / name)
            lock = root / "Packages/Granita/Package.resolved"
            lock.parent.mkdir(parents=True)
            lock.write_text('{"pins": []}\n')
            for arguments in (
                ["git", "init", "--quiet"],
                ["git", "add", "Packages/Granita/Package.resolved"],
                [
                    "git", "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
                    "-c", "user.email=coverage-fixture@example.invalid", "-c", "user.name=Coverage Fixture",
                    "commit", "--quiet", "-m", "Coverage simulator fixture",
                ],
            ):
                result = subprocess.run(arguments, capture_output=True, check=False, cwd=root, text=True)
                assert result.returncode == 0, result.stdout + result.stderr
            inventory = root / "devices.txt"
            inventory.write_text(dedent("""\
                == Devices ==
                -- iOS 27.0 --
                    iPhone 18 Pro (11111111-1111-1111-1111-111111111111) (Shutdown)
                    iPhone 18 (22222222-2222-2222-2222-222222222222) (Shutdown)
                """))
            tools = root / "tools"
            tools.mkdir()
            for executable, fake in (
                ("xcodebuild", "fake_simulator_xcodebuild.py"),
                ("xcrun", "fake_simulator_discovery.py"),
            ):
                shutil.copyfile(source / ".github/scripts" / fake, tools / executable)
                (tools / executable).chmod(0o755)
            self.receipt = root / "tool-calls.txt"
            self.environment = dict(os.environ)
            self.environment.update({
                "FAKE_SIMULATOR_DEVICE_LIST": str(inventory),
                "FAKE_SIMULATOR_TOOL_CALLS": str(self.receipt),
                "IOS_SIM_ID": selected_uuid,
                "PATH": str(tools) + os.pathsep + os.environ.get("PATH", ""),
            })
