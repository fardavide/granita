"""Tests for coverage.py.

The gate's arithmetic decides whether a pull request can merge, so it is verified by the job that
enforces it, before it is enforced. That is cheap enough that it never justifies skipping.
"""

from __future__ import annotations

import json

import coverage


def counter(covered: int, count: int) -> dict:
    return {"covered": covered, "count": count}


def summary(total: tuple[int, int], modules: dict[str, tuple[int, int]], ref: str = "main") -> dict:
    return {
        "ref": ref,
        "totals": counter(*total),
        "modules": {name: counter(*value) for name, value in modules.items()},
    }


class TestPathClassification:

    def test_given_a_tests_directory_when_classifying_then_it_is_a_test_path(self):
        assert coverage.is_test_path("Client/Connection/DataTests/BonjourTests.swift")
        assert coverage.is_test_path("Core/Diff/DomainTests/ParserTests.swift")

    def test_given_shipped_code_when_classifying_then_it_is_not_a_test_path(self):
        assert not coverage.is_test_path("Client/Connection/Data/Bonjour.swift")
        # The suffix must be on a directory, not on the file — a shipped type may be named for tests.
        assert not coverage.is_test_path("Core/Diff/Domain/FixtureTests.swift")

    def test_given_a_source_path_when_deriving_the_module_then_it_matches_the_manifest(self):
        assert coverage.module_of("Client/Viewer/Data/Fetch.swift") == "ClientViewerData"
        assert coverage.module_of("Server/Api/Presentation/Router.swift") == "ServerApiPresentation"


class TestGate:

    def test_given_coverage_is_unchanged_when_gating_then_it_passes(self):
        # given
        current = summary((50, 100), {"CoreDiffDomain": (50, 100)})

        # when
        verdict = coverage.verdict_for(current, current)

        # then
        assert verdict["ok"]

    def test_given_a_module_went_backwards_when_gating_then_it_fails_and_names_it(self):
        # given
        baseline = summary((50, 100), {"CoreDiffDomain": (50, 100)})
        current = summary((40, 100), {"CoreDiffDomain": (40, 100)})

        # when
        verdict = coverage.verdict_for(current, baseline)

        # then
        assert not verdict["ok"]
        assert {r["name"] for r in verdict["regressions"]} == {"total", "CoreDiffDomain"}

    def test_given_coverage_improved_when_gating_then_it_passes(self):
        # given
        baseline = summary((50, 100), {"CoreDiffDomain": (50, 100)})
        current = summary((80, 100), {"CoreDiffDomain": (80, 100)})

        # when - then
        assert coverage.verdict_for(current, baseline)["ok"]

    def test_given_a_new_module_when_gating_then_it_is_not_checked(self):
        # given — a module absent from the baseline has nothing to regress against.
        baseline = summary((50, 100), {"CoreDiffDomain": (50, 100)})
        current = summary((25, 200), {"CoreDiffDomain": (50, 100), "CoreTreeDomain": (0, 100)})

        # when
        verdict = coverage.verdict_for(current, baseline)

        # then — the new module is unchecked, but it still drags the total down, and the total IS
        # checked. Adding untested code is a regression even when no existing module moved.
        assert {c["name"] for c in verdict["checks"]} == {"total", "CoreDiffDomain"}
        assert not verdict["ok"]
        assert [r["name"] for r in verdict["regressions"]] == ["total"]

    def test_given_a_module_was_deleted_when_gating_then_it_is_not_a_regression(self):
        # given
        baseline = summary((50, 100), {"CoreDiffDomain": (25, 50), "Gone": (25, 50)})
        current = summary((25, 50), {"CoreDiffDomain": (25, 50)})

        # when - then
        assert coverage.verdict_for(current, baseline)["ok"]

    def test_given_no_baseline_when_gating_then_nothing_is_enforced(self):
        # given — the first run on a fresh cache has nothing to compare against.
        current = summary((0, 100), {"CoreDiffDomain": (0, 100)})

        # when
        verdict = coverage.verdict_for(current, None)

        # then
        assert verdict["ok"]
        assert not verdict["compared"]

    def test_given_an_empty_module_when_gating_then_it_is_skipped_rather_than_dividing_by_zero(self):
        # given — a module of pure declarations reports no countable lines.
        baseline = summary((50, 100), {"Empty": (0, 0)})
        current = summary((50, 100), {"Empty": (0, 0)})

        # when
        verdict = coverage.verdict_for(current, baseline)

        # then
        assert verdict["ok"]
        assert "Empty" not in {c["name"] for c in verdict["checks"]}


class TestCollect:

    def test_given_an_llvm_export_when_collecting_then_tests_and_dependencies_are_excluded(self, tmp_path):
        # given
        def file_entry(name: str, covered: int, count: int) -> dict:
            return {"filename": name, "summary": {"lines": {"covered": covered, "count": count}}}

        root = "/repo/Packages/Granita/"
        export = {"data": [{"files": [
            file_entry(f"{root}Client/Connection/Domain/Server.swift", 8, 10),
            file_entry(f"{root}Client/Connection/DomainTests/ServerTests.swift", 40, 40),
            file_entry(f"{root}.build/checkouts/hummingbird/Sources/App.swift", 100, 100),
            file_entry("/somewhere/else/Other.swift", 1, 1),
        ]}]}
        export_path = tmp_path / "export.json"
        export_path.write_text(json.dumps(export))
        out = tmp_path / "summary.json"

        # when
        coverage.main(["collect", "--export", str(export_path), "--out", str(out), "--ref", "main"])

        # then — only the shipped source counts.
        result = json.loads(out.read_text())
        assert result["totals"] == {"covered": 8, "count": 10}
        assert result["modules"] == {"ClientConnectionDomain": {"covered": 8, "count": 10}}


class TestEnforce:

    def test_given_a_regression_when_enforcing_then_it_exits_non_zero(self, tmp_path):
        # given
        verdict = tmp_path / "verdict.json"
        verdict.write_text(json.dumps(coverage.verdict_for(
            summary((40, 100), {"CoreDiffDomain": (40, 100)}),
            summary((50, 100), {"CoreDiffDomain": (50, 100)}),
        )))

        # when - then
        assert coverage.main(["enforce", "--verdict", str(verdict)]) == 1

    def test_given_coverage_held_when_enforcing_then_it_exits_zero(self, tmp_path):
        # given
        held = summary((50, 100), {"CoreDiffDomain": (50, 100)})
        verdict = tmp_path / "verdict.json"
        verdict.write_text(json.dumps(coverage.verdict_for(held, held)))

        # when - then
        assert coverage.main(["enforce", "--verdict", str(verdict)]) == 0


class TestRender:

    def test_given_a_baseline_when_rendering_then_the_comment_carries_a_marker_and_the_deltas(self, tmp_path):
        # given
        current_path = tmp_path / "current.json"
        baseline_path = tmp_path / "baseline.json"
        current_path.write_text(json.dumps(summary((60, 100), {"CoreDiffDomain": (60, 100)})))
        baseline_path.write_text(json.dumps(summary((50, 100), {"CoreDiffDomain": (50, 100)})))
        comment = tmp_path / "comment.md"

        # when
        coverage.main([
            "render", "--current", str(current_path), "--baseline", str(baseline_path),
            "--out", str(comment), "--verdict-out", str(tmp_path / "verdict.json"),
        ])

        # then — the marker is what lets CI rewrite one comment instead of appending a transcript.
        body = comment.read_text()
        assert "<!-- granita-coverage-report -->" in body
        assert "60.0%  +10.0" in body

    def test_given_no_baseline_when_rendering_then_it_says_so_rather_than_showing_false_deltas(self, tmp_path):
        # given
        current_path = tmp_path / "current.json"
        current_path.write_text(json.dumps(summary((60, 100), {"CoreDiffDomain": (60, 100)})))
        comment = tmp_path / "comment.md"

        # when
        coverage.main([
            "render", "--current", str(current_path), "--baseline", str(tmp_path / "absent.json"),
            "--out", str(comment), "--verdict-out", str(tmp_path / "verdict.json"),
        ])

        # then
        body = comment.read_text()
        assert "No baseline yet" in body
        assert "(new)" in body
