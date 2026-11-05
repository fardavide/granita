"""Simulator discovery keeps snapshots on their exact baseline runtime."""

import os
from pathlib import Path
import shutil
import subprocess
from textwrap import dedent

import pytest


class TestSimulatorSelection:
    @pytest.mark.parametrize(
        ("devices", "expected_uuid", "phone_name"),
        [
            pytest.param(
                dedent(
                    """\
                    == Devices ==
                    -- iOS 26.5 --
                        iPhone 17 Pro (11111111-1111-1111-1111-111111111111) (Shutdown)
                        iPhone 17 (22222222-2222-2222-2222-222222222222) (Shutdown)
                    -- iOS 27.0 --
                        iPad Pro 13-inch (33333333-3333-3333-3333-333333333333) (Shutdown)
                        iPhone 18 Pro (44444444-4444-4444-4444-444444444444) (Shutdown)
                        iPhone 18 (55555555-5555-5555-5555-555555555555) (Shutdown)
                    -- watchOS 27.0 --
                        Apple Watch Series 12 (66666666-6666-6666-6666-666666666666) (Shutdown)
                    """
                ),
                "44444444-4444-4444-4444-444444444444",
                None,
                id="first-supported-baseline-phone",
            ),
            pytest.param(
                dedent(
                    """\
                    == Devices ==
                    -- iOS 26.5 --
                        iPhone 17 Pro (11111111-1111-1111-1111-111111111111) (Shutdown)
                        iPhone 17 (22222222-2222-2222-2222-222222222222) (Shutdown)
                    -- iOS 27.0 --
                        iPhone Duo (33333333-3333-3333-3333-333333333333) (Shutdown)
                    """
                ),
                None,
                None,
                id="baseline-duo-does-not-fall-back-to-older-runtime",
            ),
            pytest.param(
                dedent(
                    """\
                    == Devices ==
                    -- iOS 27.0 --
                        iPhone Duo (11111111-1111-1111-1111-111111111111) (Shutdown)
                    """
                ),
                None,
                None,
                id="no-supported-phone",
            ),
            pytest.param(
                dedent(
                    """\
                    == Devices ==
                    -- iOS 27.0 --
                        iPhone 18 Pro (11111111-1111-1111-1111-111111111111) (Shutdown)
                    -- iOS 27.2 --
                        iPhone 18 Pro (22222222-2222-2222-2222-222222222222) (Shutdown)
                    """
                ),
                "11111111-1111-1111-1111-111111111111",
                None,
                id="duplicate-phone-under-newer-runtime",
            ),
            pytest.param(
                dedent(
                    """\
                    == Devices ==
                    -- iOS 26.5 --
                        iPhone 17 Pro (11111111-1111-1111-1111-111111111111) (Shutdown)
                    -- iOS 27.2 --
                        iPhone 18 Pro (22222222-2222-2222-2222-222222222222) (Shutdown)
                    """
                ),
                None,
                None,
                id="missing-baseline-runtime",
            ),
            pytest.param(
                dedent(
                    """\
                    == Devices ==
                    -- iOS 27.0 --
                        iPhone 18 Pro (11111111-1111-1111-1111-111111111111) (Shutdown)
                        iPhone 18 (22222222-2222-2222-2222-222222222222) (Shutdown)
                    -- iOS 27.2 --
                        iPhone 18 (33333333-3333-3333-3333-333333333333) (Shutdown)
                    """
                ),
                "22222222-2222-2222-2222-222222222222",
                "iPhone 18",
                id="exact-phone-name-override",
            ),
            pytest.param(
                dedent(
                    """\
                    == Devices ==
                    -- iOS 27.0 --
                        iPhone 18 Pro (11111111-1111-1111-1111-111111111111) (Shutdown)
                    -- iOS 27.2 --
                        iPhone 18 (22222222-2222-2222-2222-222222222222) (Shutdown)
                    """
                ),
                None,
                "iPhone 18",
                id="requested-phone-missing-from-baseline-runtime",
            ),
        ],
    )
    def test_given_available_devices_when_selecting_then_only_baseline_runtime_is_eligible(
        self: "TestSimulatorSelection",
        devices: str,
        expected_uuid: str | None,
        phone_name: str | None,
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(devices=devices, root=tmp_path)
        arguments = ["bash", ".github/scripts/ios-simulator.sh"]
        if phone_name is not None:
            arguments.append(phone_name)

        # when
        result = subprocess.run(
            arguments,
            capture_output=True,
            check=False,
            cwd=scenario.source,
            env=scenario.environment,
            text=True,
        )

        # then
        if expected_uuid is None:
            assert result.returncode != 0, result.stdout + result.stderr
            assert result.stdout.strip() == ""
            assert "27.0" in result.stderr
            assert "phone" in result.stderr.lower()
            if phone_name is not None:
                assert phone_name in result.stderr
        else:
            assert result.returncode == 0, result.stderr
            assert result.stdout.strip() == expected_uuid

    class Scenario:
        def __init__(
            self: "TestSimulatorSelection.Scenario",
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
