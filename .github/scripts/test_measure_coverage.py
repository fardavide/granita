"""Required suite counters stay isolated when the aggregation shell runs."""

import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
from typing import TypedDict

import pytest


class FileEntry(TypedDict):
    path: str
    sha256: str


class Manifest(TypedDict):
    complete: bool
    files: list[FileEntry]
    run: str
    schema: int
    source_digest: str
    source_revision: str
    source_root: str
    suite: str
    toolchain: str


class TestMeasureCoverage:
    @pytest.mark.parametrize("missing_path", ["manifest.json", "objects/object-0", "profile.profdata"])
    def test_given_missing_ui_artifact_when_aggregating_then_refuses_before_reading_counters(
        self: "TestMeasureCoverage",
        missing_path: str,
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path, Path(__file__).resolve().parents[2] / ".github/scripts")
        (tmp_path / "build/coverage-inputs/ui" / missing_path).unlink()

        # when
        result = scenario.run(["bash", ".github/scripts/measure-coverage.sh"])

        # then
        assert result.returncode != 0, result.stdout + result.stderr
        assert missing_path in result.stderr
        assert not (tmp_path / "tool-calls.jsonl").exists()

    def test_given_required_suite_artifacts_when_aggregating_then_ui_counters_stay_out_of_snapshot(
        self: "TestMeasureCoverage",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path, Path(__file__).resolve().parents[2] / ".github/scripts")

        # when
        result = scenario.run(["bash", ".github/scripts/measure-coverage.sh"])

        # then
        assert result.returncode == 0, result.stdout + result.stderr
        summary: object = json.loads((tmp_path / "build/coverage/summary.json").read_text())
        assert isinstance(summary, dict)
        categories: object = summary.get("categories")
        assert isinstance(categories, dict)
        assert set(categories) == {"all", "snapshot", "ui", "unit"}
        self._assert_counters(categories["unit"], covered=2, count=4)
        self._assert_counters(categories["ui"], covered=28, count=32)
        self._assert_counters(categories["snapshot"], covered=15, count=30)
        self._assert_counters(categories["all"], covered=13, count=17)

        exports: dict[str, list[str]] = {}
        for arguments in scenario.calls():
            if arguments[:2] != ["llvm-cov", "export"]:
                continue
            profile = Path(arguments[arguments.index("-instr-profile") + 1])
            category = profile.parent.name if profile.name == "profile.profdata" else profile.stem
            assert category not in exports, f"Repeated {category} export: {arguments}"
            exports[category] = arguments
        assert set(exports) == {"all", "snapshot", "ui", "unit"}
        expected_suites = {
            "all": {"ios-0", "ios-1", "mac", "ui", "unit"},
            "snapshot": {"ios-0", "ios-1", "mac"},
            "ui": {"ui"},
            "unit": {"unit"},
        }
        for category, arguments in exports.items():
            profile = Path(arguments[arguments.index("-instr-profile") + 1])
            assert set(profile.read_text().splitlines()) == expected_suites[category]
            objects = [
                Path(arguments[index + 1])
                for index, argument in enumerate(arguments)
                if argument == "-object"
            ]
            assert len(objects) == len(set(objects)), f"Repeated {category} mapping"
            assert set(objects) == {
                mapping
                for suite in expected_suites[category]
                for mapping in (tmp_path / "build/coverage-inputs" / suite / "objects").iterdir()
            }

    def _assert_counters(
        self: "TestMeasureCoverage",
        category: object,
        covered: int,
        count: int,
    ) -> None:
        assert isinstance(category, dict)
        for counter in ("lines", "regions"):
            assert category[counter] == {"count": count, "covered": covered}

    class _Scenario:
        def __init__(
            self: "TestMeasureCoverage._Scenario",
            root: Path,
            scripts: Path,
        ) -> None:
            self.root = root
            self.environment = dict(os.environ)
            self.environment.update({
                "GITHUB_REF_NAME": "fixture",
                "GITHUB_RUN_ATTEMPT": "1",
                "GITHUB_RUN_ID": "fixture",
            })
            destination = root / ".github/scripts"
            destination.mkdir(parents=True)
            for name in (
                "coverage.py",
                "coverage_artifacts.py",
                "measure-coverage.sh",
                "snapshot_shards.py",
                "source_digest.py",
            ):
                shutil.copyfile(scripts / name, destination / name)
            lock = root / "Packages/Granita/Package.resolved"
            lock.parent.mkdir(parents=True)
            lock.write_text('{"pins": []}\n')
            self._checked_run(["git", "init", "--quiet"])
            self._checked_run(["git", "add", ".github/scripts", "Packages/Granita/Package.resolved"])
            self._checked_run([
                "git", "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
                "-c", "user.email=coverage-fixture@example.invalid", "-c", "user.name=Coverage Fixture",
                "commit", "--quiet", "-m", "Coverage fixture",
            ])
            self.environment["GITHUB_SHA"] = self._checked_run(["git", "rev-parse", "HEAD"]).stdout.strip()

            tools = root / "tools"
            tools.mkdir()
            (tools / "xcodebuild").write_text(
                f"#!{sys.executable}\n"
                "import sys\n"
                "assert sys.argv[1:] == ['-version'], sys.argv\n"
                "print('Xcode Fixture\\nBuild version Fixture')\n"
            )
            (tools / "xcrun").write_text(f"#!{sys.executable}\n" + FAKE_XCRUN)
            for tool in tools.iterdir():
                tool.chmod(0o755)
            # Only this child process resolves fake platform tools; host configuration is untouched.
            self.environment["PATH"] = str(tools) + os.pathsep + os.environ.get("PATH", "")
            digest = self._checked_run([sys.executable, ".github/scripts/source_digest.py"]).stdout.strip()
            for suite in ("ios-0", "ios-1", "mac", "ui", "unit"):
                self._artifact(digest, suite)

        def calls(self: "TestMeasureCoverage._Scenario") -> list[list[str]]:
            calls: list[list[str]] = []
            for line in (self.root / "tool-calls.jsonl").read_text().splitlines():
                arguments: object = json.loads(line)
                assert isinstance(arguments, list)
                assert all(isinstance(argument, str) for argument in arguments)
                calls.append([argument for argument in arguments if isinstance(argument, str)])
            return calls

        def run(
            self: "TestMeasureCoverage._Scenario",
            arguments: list[str],
        ) -> subprocess.CompletedProcess[str]:
            return subprocess.run(
                arguments,
                capture_output=True,
                check=False,
                cwd=self.root,
                env=self.environment,
                text=True,
            )

        def _artifact(
            self: "TestMeasureCoverage._Scenario",
            digest: str,
            suite: str,
        ) -> None:
            directory = self.root / "build/coverage-inputs" / suite
            objects = directory / "objects"
            objects.mkdir(parents=True)
            (directory / "profile.profdata").write_text(suite + "\n")
            for index in range(1 if suite == "unit" else 3):
                (objects / f"object-{index}").write_text(suite + "\n")
            if suite == "unit":
                (directory / "tests.log").write_text("Test run with 1 tests passed after 0.001 seconds.\n")
            else:
                identifier = {
                    "ios-0": "GranitaMobileSnapshotTests/FirstSnapshots/testRender()",
                    "ios-1": "GranitaMobileSnapshotTests/SecondSnapshots/testRender()",
                    "mac": "GranitaMacSnapshotTests/MacSnapshots/testRender()",
                    "ui": "GranitaMobileUiTests/CommentInteractionTests/testTouch()",
                }[suite]
                (directory / "test-summary.json").write_text(json.dumps({
                    "failedTests": 0,
                    "passedTests": 1,
                    "result": "Passed",
                    "skippedTests": 0,
                    "totalTestCount": 1,
                }))
                (directory / "test-inventory.json").write_text(json.dumps({
                    "testNodes": [{
                        "nodeIdentifier": identifier.split("/", 1)[1],
                        "nodeType": "Test Case",
                        "result": "Passed",
                    }],
                }))
                if suite in ("ios-0", "ios-1", "ui"):
                    enabled = [identifier] if suite == "ui" else [
                        "GranitaMobileSnapshotTests/FirstSnapshots/testRender()",
                        "GranitaMobileSnapshotTests/SecondSnapshots/testRender()",
                    ]
                    (directory / "enumerated-tests.json").write_text(json.dumps({
                        "errors": [],
                        "values": [{
                            "disabledTests": [],
                            "enabledTests": [{"identifier": item} for item in enabled],
                            "testPlan": "Fixture",
                        }],
                    }))
                    if suite != "ui":
                        (directory / "planned-tests.json").write_text(json.dumps([identifier]))
            entries: list[FileEntry] = [
                {"path": str(path.relative_to(directory)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                for path in sorted(directory.rglob("*"))
                if path.is_file()
            ]
            manifest: Manifest = {
                "complete": True,
                "files": entries,
                "run": "fixture:1",
                "schema": 1,
                "source_digest": digest,
                "source_revision": self.environment["GITHUB_SHA"],
                "source_root": str(self.root),
                "suite": suite,
                "toolchain": f"Xcode Fixture\nBuild version Fixture {platform.machine()}",
            }
            (directory / "manifest.json").write_text(json.dumps(manifest))

        def _checked_run(
            self: "TestMeasureCoverage._Scenario",
            arguments: list[str],
        ) -> subprocess.CompletedProcess[str]:
            result = self.run(arguments)
            assert result.returncode == 0, result.stdout + result.stderr
            return result


FAKE_XCRUN = '''import json
from pathlib import Path
import sys


arguments = sys.argv[1:]
root = Path(__file__).resolve().parent.parent
with (root / "tool-calls.jsonl").open("a") as receipt:
    receipt.write(json.dumps(arguments) + "\\n")

if arguments[:2] == ["llvm-profdata", "merge"]:
    output_index = arguments.index("-o")
    profiles = [argument for argument in arguments[2:output_index] if not argument.startswith("-")]
    markers = {marker for profile in profiles for marker in Path(profile).read_text().splitlines()}
    Path(arguments[output_index + 1]).write_text("".join(marker + "\\n" for marker in sorted(markers)))
elif arguments[:2] == ["llvm-cov", "export"]:
    assert "--check-binary-ids" in arguments, arguments
    profile = Path(arguments[arguments.index("-instr-profile") + 1])
    covered_suites = set(profile.read_text().splitlines())
    mapped_suites = {
        Path(arguments[index + 1]).read_text().strip()
        for index, argument in enumerate(arguments)
        if argument == "-object"
    }
    assert covered_suites <= mapped_suites, (covered_suites, mapped_suites)
    counters: dict[str, list[tuple[str, int, int]]] = {
        "ios-0": [("Ui", 3, 10)],
        "ios-1": [("Ui", 5, 10)],
        "mac": [("Ui", 7, 10)],
        "ui": [("Domain", 11, 13), ("Ui", 17, 19)],
        "unit": [("Domain", 2, 4)],
    }
    files = [
        {
            "filename": str(root / "Packages/Granita/Client/Viewer" / layer / (suite + ".swift")),
            "summary": {
                counter: {"count": count, "covered": covered if suite in covered_suites else 0}
                for counter in ("lines", "regions")
            },
        }
        for suite in sorted(mapped_suites)
        for layer, covered, count in counters[suite]
    ]
    print(json.dumps({"data": [{"files": files, "functions": []}]}))
else:
    raise AssertionError(f"Unexpected platform command: {arguments}")
'''

