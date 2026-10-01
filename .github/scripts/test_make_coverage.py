"""The coverage tooling must not start unrelated platform tooling."""

from pathlib import Path
import subprocess


class TestMakeCoverage:
    def test_given_coverage_script_tests_when_planned_then_simulator_discovery_is_unused(
        self: "TestMakeCoverage",
    ) -> None:
        # given
        root = Path(__file__).resolve().parents[2]

        # when
        result = subprocess.run(
            [
                "make",
                "-n",
                "coverage-tests",
                "IOS_SIM_NAME=$(error unexpected simulator discovery)",
            ],
            capture_output=True,
            check=False,
            cwd=root,
            text=True,
        )

        # then
        assert result.returncode == 0, result.stderr
        assert "unexpected simulator discovery" not in result.stderr
