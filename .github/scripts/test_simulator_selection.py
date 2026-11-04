"""Simulator discovery selects the newest runtime with a supported numbered phone."""

from pathlib import Path
import re
import subprocess
from textwrap import dedent

import pytest


class TestSimulatorSelection:
    @pytest.mark.parametrize(
        ("selection_pattern", "source_path"),
        [
            pytest.param(
                r"(?m)^IOS_SIM_NAME = .*?awk '([^']+)'",
                Path("Makefile"),
                id="makefile",
            ),
            pytest.param(
                r"(?s)id: simulator\s+run: \|.*?name=\"\$\(awk '([^']+)'",
                Path(".github/workflows/ci.yml"),
                id="ci-simulator-step",
            ),
            pytest.param(
                r"(?m)^\s*SIMULATOR=.*?awk '([^']+)'",
                Path(".github/scripts/collect-coverage.sh"),
                id="coverage-collector",
            ),
            pytest.param(
                r"(?m)^SIMULATOR=.*?awk '([^']+)'",
                Path(".github/scripts/measure-coverage-legacy.sh"),
                id="legacy-coverage",
            ),
        ],
    )
    @pytest.mark.parametrize(
        ("devices", "expected_name"),
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
                "iPhone 18 Pro",
                id="newest-supported-runtime",
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
                "iPhone 17 Pro",
                id="newer-duo-only-runtime",
            ),
            pytest.param(
                dedent(
                    """\
                    == Devices ==
                    -- iOS 27.0 --
                        iPhone Duo (11111111-1111-1111-1111-111111111111) (Shutdown)
                    """
                ),
                "",
                id="no-supported-phone",
            ),
        ],
    )
    def test_given_runtime_devices_when_selecting_then_uses_first_phone_in_newest_supported_runtime(
        self: "TestSimulatorSelection",
        devices: str,
        expected_name: str,
        selection_pattern: str,
        source_path: Path,
    ) -> None:
        # given
        root = Path(__file__).resolve().parents[2]
        source = (root / source_path).read_text()
        expression_match = re.search(selection_pattern, source)
        assert expression_match is not None, f"No simulator selector found in {source_path}"
        expression = expression_match.group(1).replace("$$", "$")

        # when
        result = subprocess.run(
            ["awk", expression],
            capture_output=True,
            check=False,
            input=devices,
            text=True,
        )

        # then
        assert result.returncode == 0, result.stderr
        assert result.stdout.strip() == expected_name
