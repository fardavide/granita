import mac_release
from pathlib import Path


class TestMacRelease:
    def test_given_historical_revision_when_workflow_publishes_then_uses_scoped_release_token(self: "TestMacRelease") -> None:
        # given
        workflow = (Path(__file__).parents[1] / "workflows/mac-release.yml").read_text()
        # when
        publish_step = workflow.split("      - name: Fetch, package, notarize and publish\n", 1)[1].split("      - name:", 1)[0]
        # then
        assert "GH_TOKEN: ${{ secrets.MAC_RELEASE_GITHUB_TOKEN }}" in publish_step

    def test_given_project_manifest_when_reading_version_then_uses_shared_marketing_version(self: "TestMacRelease") -> None:
        # given
        manifest = "settingGroups:\n  shared:\n    MARKETING_VERSION: 0.22.0\n    CURRENT_PROJECT_VERSION: 1\n"
        # when
        version = mac_release.project_version(manifest)
        # then
        assert version == "0.22.0"

    def test_given_other_revision_when_selecting_cloud_build_then_it_waits(self: "TestMacRelease") -> None:
        # given
        builds: list[dict[str, object]] = []
        # when
        result = mac_release.select_build(builds, "a" * 40)
        # then
        assert result is None

    def test_given_multiple_versions_when_extracting_notes_then_only_requested_release_is_used(self: "TestMacRelease") -> None:
        # given
        changelog = "# Changelog\n\n### 0.22.0 — 2026-10-02\n\n- **One Mac app.** Read local worktrees.\n\n### 0.21.0 — 2026-09-29\n\n- Old change.\n"
        # when
        notes = mac_release.release_notes(changelog, "0.22.0")
        # then
        assert notes == "- **One Mac app.** Read local worktrees.\n"
