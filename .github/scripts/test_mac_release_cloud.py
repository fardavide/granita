"""Select the notarized Xcode Cloud export for a specific source commit."""

from pathlib import Path

import mac_release
import pytest


class FakeAppleClient:
    def __init__(self: "FakeAppleClient") -> None:
        self.downloads: list[tuple[str, Path]] = []
        self.responses: dict[str, list[dict[str, object]]] = {
            "ciBuildActions/archive/artifacts?limit=200": [
                {
                    "attributes": {
                        "fileName": "Granita.zip",
                        "fileType": "ARCHIVE",
                    },
                    "id": "unnotarized",
                },
                {
                    "attributes": {
                        "fileName": "Granita-notarized.zip",
                        "fileType": "STAPLED_NOTARIZED_ARCHIVE",
                    },
                    "id": "notarized",
                },
            ],
            "ciBuildRuns/build42/actions?limit=200": [
                {
                    "attributes": {
                        "actionType": "ARCHIVE",
                        "completionStatus": "SUCCEEDED",
                        "executionProgress": "COMPLETE",
                    },
                    "id": "archive",
                },
            ],
            "ciWorkflows/mac-workflow/buildRuns?sort=-number&limit=200": [
                {
                    "attributes": {
                        "completionStatus": "SUCCEEDED",
                        "executionProgress": "COMPLETE",
                        "isPullRequestBuild": False,
                        "number": 43,
                        "sourceCommit": {"commitSha": "b" * 40},
                    },
                    "id": "unrelated-build43",
                },
                {
                    "attributes": {
                        "completionStatus": "SUCCEEDED",
                        "executionProgress": "COMPLETE",
                        "isPullRequestBuild": False,
                        "number": 42,
                        "sourceCommit": {"commitSha": "a" * 40},
                    },
                    "id": "build42",
                },
            ],
        }

    def download(
        self: "FakeAppleClient",
        artifact_id: str,
        destination: Path,
    ) -> None:
        self.downloads.append((artifact_id, destination))
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(b"downloaded zip placeholder")

    def resources(
        self: "FakeAppleClient",
        path: str,
    ) -> list[dict[str, object]]:
        return self.responses[path]


class TestFetchNotarizedExport:
    def test_given_exact_commit_when_notarized_export_exists_then_downloads_export_and_returns_build_number(
        self: "TestFetchNotarizedExport",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)

        # when
        archive, build_number = mac_release.fetch_notarized_export(
            client=scenario.client,
            output=scenario.output,
            revision="a" * 40,
            workflow_id="mac-workflow",
        )

        # then
        assert scenario.client.downloads == [("notarized", archive)]
        assert archive.read_bytes() == b"downloaded zip placeholder"
        assert build_number == 42

    def test_given_failed_exact_commit_build_when_export_requested_then_fails_without_download(
        self: "TestFetchNotarizedExport",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)
        scenario.client.responses[
            "ciWorkflows/mac-workflow/buildRuns?sort=-number&limit=200"
        ] = [
            {
                "attributes": {
                    "completionStatus": "FAILED",
                    "executionProgress": "COMPLETE",
                    "isPullRequestBuild": False,
                    "number": 42,
                    "sourceCommit": {"commitSha": "a" * 40},
                },
                "id": "build42",
            },
        ]

        # when
        with pytest.raises(ValueError, match="(?i)failed|status"):
            mac_release.fetch_notarized_export(
                client=scenario.client,
                output=scenario.output,
                revision="a" * 40,
                workflow_id="mac-workflow",
            )

        # then
        assert scenario.client.downloads == []

    def test_given_ordinary_archive_export_when_notarized_export_requested_then_fails_without_download(
        self: "TestFetchNotarizedExport",
        tmp_path: Path,
    ) -> None:
        # given
        scenario = self.Scenario(tmp_path)
        scenario.client.responses["ciBuildActions/archive/artifacts?limit=200"] = [
            {
                "attributes": {
                    "fileName": "Granita.zip",
                    "fileType": "ARCHIVE_EXPORT",
                },
                "id": "unnotarized",
            },
        ]

        # when
        with pytest.raises(ValueError, match="(?i)notarized"):
            mac_release.fetch_notarized_export(
                client=scenario.client,
                output=scenario.output,
                revision="a" * 40,
                workflow_id="mac-workflow",
            )

        # then
        assert scenario.client.downloads == []

    class Scenario:
        def __init__(
            self: "TestFetchNotarizedExport.Scenario",
            directory: Path,
        ) -> None:
            self.client = FakeAppleClient()
            self.output = directory / "exports"
