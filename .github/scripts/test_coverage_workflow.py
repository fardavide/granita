"""A runner cache miss must not silently disable the pull request's coverage ratchet."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from textwrap import dedent
from typing import TypedDict

import coverage


class Counter(TypedDict):
    count: int
    covered: int


class Category(TypedDict):
    lines: Counter
    regions: Counter
    scope: str


class Summary(TypedDict):
    categories: dict[str, Category]
    commit: str
    ref: str


class TestCoverageWorkflow:
    def test_given_empty_cache_and_saved_main_summary_when_reporting_then_unit_and_all_regressions_are_enforced(
        self: "TestCoverageWorkflow",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)

        # when
        acquisition = subprocess.run(
            ["bash", "-euo", "pipefail", "-c", scenario.acquisition],
            capture_output=True,
            check=False,
            cwd=tmp_path,
            env=scenario.environment,
            text=True,
        )
        assert acquisition.returncode == 0, acquisition.stdout + acquisition.stderr
        report = subprocess.run(
            ["bash", "-euo", "pipefail", "-c", scenario.report],
            capture_output=True,
            check=False,
            cwd=tmp_path,
            env=scenario.environment,
            text=True,
        )
        assert report.returncode == 0, report.stdout + report.stderr
        enforcement = subprocess.run(
            ["bash", "-euo", "pipefail", "-c", scenario.enforcement],
            capture_output=True,
            check=False,
            cwd=tmp_path,
            env=scenario.environment,
            text=True,
        )

        # then
        assert enforcement.returncode == 1, enforcement.stdout + enforcement.stderr
        verdict: object = json.loads((tmp_path / "build/coverage/verdict.json").read_text())
        assert isinstance(verdict, dict)
        assert verdict["status"] == "fail"
        checks: object = verdict["checks"]
        assert isinstance(checks, list)
        assert all(isinstance(check, dict) for check in checks)
        assert {check["label"] for check in checks if isinstance(check, dict)} == {
            "All tests lines",
            "All tests regions",
            "Unit lines",
            "Unit regions",
        }
        assert all(check["status"] == "fail" for check in checks if isinstance(check, dict))
        assert json.loads((tmp_path / ".coverage-baseline/summary.json").read_text()) == scenario.baseline

    class Scenario:
        def __init__(self: "TestCoverageWorkflow.Scenario", root: Path) -> None:
            source = Path(__file__).resolve().parents[2]
            workflow = (source / ".github/workflows/ci.yml").read_text()
            acquisition_start = workflow.index("      - name: Restore the main coverage baseline\n")
            acquisition_end = workflow.index("      - name: Download unit coverage\n", acquisition_start)
            run_pattern = r"(?m)^        run: (?:\|\n((?:          [^\n]*\n|\n)+)|([^\n]+))"
            self.acquisition = "\n".join(
                dedent(match.group(1)) if match.group(1) is not None else match.group(2)
                for match in re.finditer(run_pattern, workflow[acquisition_start:acquisition_end])
            )
            report_match = re.search(
                r"      - name: Render the report\n" + run_pattern.removeprefix("(?m)"),
                workflow,
                re.MULTILINE,
            )
            assert report_match is not None, "Coverage report command missing from workflow"
            self.report = dedent(report_match.group(1)) if report_match.group(1) is not None else report_match.group(2)
            enforcement_match = re.search(
                r"      - name: Enforce the coverage gate\n(?:        if: [^\n]+\n)?"
                + run_pattern.removeprefix("(?m)"),
                workflow,
                re.MULTILINE,
            )
            assert enforcement_match is not None, "Coverage enforcement command missing from workflow"
            self.enforcement = (
                dedent(enforcement_match.group(1))
                if enforcement_match.group(1) is not None
                else enforcement_match.group(2)
            )

            scripts = root / ".github/scripts"
            scripts.mkdir(parents=True)
            shutil.copyfile(source / ".github/scripts/coverage.py", scripts / "coverage.py")
            (root / "Scripts").mkdir()
            shutil.copy2(source / "Scripts/fetch-coverage-baseline.sh", root / "Scripts/fetch-coverage-baseline.sh")

            self.baseline: Summary = {
                "categories": {
                    "all": {
                        "lines": {"count": 100, "covered": 95},
                        "regions": {"count": 50, "covered": 48},
                        "scope": coverage.HOST_REACHABLE_SCOPE,
                    },
                    "snapshot": {
                        "lines": {"count": 100, "covered": 90},
                        "regions": {"count": 50, "covered": 45},
                        "scope": "rendering-views-before-input-scope-change",
                    },
                    "unit": {
                        "lines": {"count": 100, "covered": 90},
                        "regions": {"count": 50, "covered": 45},
                        "scope": coverage.HOST_REACHABLE_SCOPE,
                    },
                },
                "commit": "saved-main-revision",
                "ref": "main",
            }
            (root / "saved-main-summary.json").write_text(json.dumps(self.baseline))
            current: Summary = {
                "categories": {
                    "all": {
                        "lines": {"count": 100, "covered": 85},
                        "regions": {"count": 50, "covered": 43},
                        "scope": coverage.HOST_REACHABLE_SCOPE,
                    },
                    "snapshot": {
                        "lines": {"count": 100, "covered": 20},
                        "regions": {"count": 50, "covered": 10},
                        "scope": coverage.VIEWS_SCOPE,
                    },
                    "ui": {
                        "lines": {"count": 100, "covered": 20},
                        "regions": {"count": 50, "covered": 10},
                        "scope": coverage.DEFAULT_SCOPE,
                    },
                    "unit": {
                        "lines": {"count": 100, "covered": 80},
                        "regions": {"count": 50, "covered": 40},
                        "scope": coverage.HOST_REACHABLE_SCOPE,
                    },
                },
                "commit": "pull-request-revision",
                "ref": "pull-request",
            }
            (root / "build/coverage").mkdir(parents=True)
            (root / "build/coverage/summary.json").write_text(json.dumps(current))
            tools = root / "tools"
            tools.mkdir()
            (tools / "gh").write_text(f"#!{sys.executable}\n" + FAKE_GH)
            (tools / "gh").chmod(0o755)
            self.environment = dict(os.environ)
            self.environment.update({
                "GITHUB_EVENT_NAME": "pull_request",
                "GITHUB_REF": "refs/pull/1/merge",
                "GITHUB_REPOSITORY": "fardavide/granita",
                "PATH": str(tools) + os.pathsep + os.environ.get("PATH", ""),
            })


FAKE_GH = '''from pathlib import Path
import shutil
import sys

arguments = sys.argv[1:]
assert arguments[arguments.index("--repo") + 1] == "fardavide/granita", arguments
if arguments[:2] == ["run", "list"]:
    assert arguments[arguments.index("--branch") + 1] == "main", arguments
    assert arguments[arguments.index("--status") + 1] == "success", arguments
    print("123456789")
elif arguments[:3] == ["run", "download", "123456789"]:
    assert arguments[arguments.index("-n") + 1] == "coverage-summary", arguments
    destination = Path(arguments[arguments.index("-D") + 1])
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copyfile("saved-main-summary.json", destination / "summary.json")
else:
    raise AssertionError(f"Unexpected GitHub command: {arguments}")
'''
