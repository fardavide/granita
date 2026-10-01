"""Coverage artifact identity validation tests."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import TypedDict

import pytest

import coverage_artifacts


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
    suite: str
    toolchain: str


class TestCoverageArtifacts:
    def test_given_missing_snapshot_summary_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["suite"] = "ios"
        # when
        with pytest.raises(ValueError, match="receipt") as error:
            scenario.validate()
        # then
        assert "test-summary.json" in str(error.value)

    def test_given_missing_unit_receipt_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["files"] = [
            entry for entry in scenario.manifest["files"] if entry["path"] != "tests.log"
        ]
        # when
        with pytest.raises(ValueError, match="receipt") as error:
            scenario.validate()
        # then
        assert "tests.log" in str(error.value)

    def test_given_changed_local_source_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["source_digest"] = "previous-source-digest"
        # when
        with pytest.raises(ValueError, match="source digest") as error:
            scenario.validate(expected_source_digest="current-source-digest")
        # then
        assert "previous-source-digest" in str(error.value)

    def test_given_changed_profile_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["files"] = [
            {"path": "profile.profdata", "sha256": hashlib.sha256(b"expected").hexdigest()}
        ]
        (tmp_path / "profile.profdata").write_bytes(b"actual")
        # when
        with pytest.raises(ValueError, match="digest") as error:
            scenario.validate()
        # then
        assert "profile.profdata" in str(error.value)

    def test_given_empty_file_inventory_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["files"] = []
        # when
        with pytest.raises(ValueError, match="profile and mappings") as error:
            scenario.validate()
        # then
        assert "profile and mappings" in str(error.value)

    def test_given_incompatible_toolchain_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["toolchain"] = "Xcode 26.2 Swift 6.2"
        # when
        with pytest.raises(ValueError, match="toolchain") as error:
            scenario.validate()
        # then
        assert "Xcode 26.2 Swift 6.2" in str(error.value)

    def test_given_incomplete_result_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["complete"] = False
        # when
        with pytest.raises(ValueError, match="incomplete") as error:
            scenario.validate()
        # then
        assert "incomplete" in str(error.value)

    def test_given_missing_profile_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        (tmp_path / "profile.profdata").unlink()
        # when
        with pytest.raises(ValueError, match="missing") as error:
            scenario.validate()
        # then
        assert "profile.profdata" in str(error.value)

    def test_given_parent_path_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        (tmp_path.parent / "external.profdata").write_bytes(b"external")
        scenario.manifest["files"].append(
            {"path": "../external.profdata", "sha256": hashlib.sha256(b"external").hexdigest()}
        )
        # when
        with pytest.raises(ValueError, match="path") as error:
            scenario.validate()
        # then
        assert "../external.profdata" in str(error.value)

    def test_given_previous_run_attempt_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        # when
        with pytest.raises(ValueError, match="run attempt") as error:
            scenario.validate(expected_run="36548067764:2")
        # then
        assert "36548067764:1" in str(error.value)

    def test_given_profile_without_mappings_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["files"] = [scenario.manifest["files"][0]]
        # when
        with pytest.raises(ValueError, match="profile and mappings") as error:
            scenario.validate()
        # then
        assert "profile and mappings" in str(error.value)

    def test_given_stale_revision_when_running_cli_then_exits_with_failure(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["source_revision"] = "previous-revision"
        # when
        result = subprocess.run(
            [
                sys.executable,
                str(Path(coverage_artifacts.__file__)),
                str(scenario.write_manifest()),
                "current-revision",
                "36548067764:1",
                "Xcode 26.3 Swift 6.3",
            ],
            capture_output=True,
            check=False,
            text=True,
        )
        # then
        assert result.returncode != 0
        assert "source revision" in result.stderr

    def test_given_stale_revision_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["source_revision"] = "previous-revision"
        # when
        with pytest.raises(ValueError, match="source revision") as error:
            scenario.validate()
        # then
        assert "previous-revision" in str(error.value)

    def test_given_unknown_schema_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        scenario.manifest["schema"] = 2
        # when
        with pytest.raises(ValueError, match="schema") as error:
            scenario.validate()
        # then
        assert "2" in str(error.value)

    def test_given_unlisted_mapping_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        (tmp_path / "objects" / "object-1").write_bytes(b"unlisted mapping")
        # when
        with pytest.raises(ValueError, match="inventory") as error:
            scenario.validate()
        # then
        assert "object-1" in str(error.value)

    def test_given_zero_test_receipts_when_validating_manifest_then_rejects_artifact(
        self: "TestCoverageArtifacts",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self._Scenario(tmp_path)
        receipt = b"Test run with 0 tests passed after 0.001 seconds.\n"
        (tmp_path / "tests.log").write_bytes(receipt)
        for entry in scenario.manifest["files"]:
            if entry["path"] == "tests.log":
                entry["sha256"] = hashlib.sha256(receipt).hexdigest()
        # when
        with pytest.raises(ValueError, match="test runs") as error:
            scenario.validate()
        # then
        assert "test runs" in str(error.value)

    class _Scenario:
        def __init__(self: "TestCoverageArtifacts._Scenario", root: Path) -> None:
            self.root = root
            (root / "profile.profdata").write_bytes(b"profile")
            (root / "objects").mkdir()
            (root / "objects" / "object-0").write_bytes(b"mapping")
            receipt = b"Test run with 1 tests passed after 0.001 seconds.\n"
            (root / "tests.log").write_bytes(receipt)
            self.manifest: Manifest = {
                "complete": True,
                "files": [
                    {"path": "profile.profdata", "sha256": hashlib.sha256(b"profile").hexdigest()},
                    {"path": "objects/object-0", "sha256": hashlib.sha256(b"mapping").hexdigest()},
                    {"path": "tests.log", "sha256": hashlib.sha256(receipt).hexdigest()},
                ],
                "run": "36548067764:1",
                "schema": 1,
                "source_digest": "current-source-digest",
                "source_revision": "current-revision",
                "suite": "unit",
                "toolchain": "Xcode 26.3 Swift 6.3",
            }

        def validate(
            self: "TestCoverageArtifacts._Scenario",
            expected_run: str = "36548067764:1",
            expected_source_digest: str | None = None,
        ) -> None:
            coverage_artifacts.validate_manifest(
                manifest_path=self.write_manifest(),
                expected_revision="current-revision",
                expected_run=expected_run,
                expected_source_digest=expected_source_digest,
                expected_toolchain="Xcode 26.3 Swift 6.3",
            )

        def write_manifest(self: "TestCoverageArtifacts._Scenario") -> Path:
            manifest_path = self.root / "manifest.json"
            manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
            return manifest_path
