"""Tests for coverage.py.

The gate's arithmetic decides whether a pull request can merge, so it is verified by the job that
enforces it, before it is enforced. That is cheap enough that it never justifies skipping.
"""

from __future__ import annotations

import json

import coverage


def counter(covered: int, count: int) -> dict:
    return {"covered": covered, "count": count}


def entry(lines: tuple[int, int], regions: tuple[int, int], scope: str = "package") -> dict:
    return {"lines": counter(*lines), "regions": counter(*regions), "scope": scope}


def summary(categories: dict[str, dict], ref: str = "main", commit: str = "abc1234") -> dict:
    return {"ref": ref, "commit": commit, "categories": categories}


def export(files: list[tuple[str, tuple[int, int], tuple[int, int]]]) -> dict:
    """An llvm-cov export shaped the way both SwiftPM and `xcrun llvm-cov` emit it."""
    return {
        "data": [
            {
                "files": [
                    {
                        "filename": name,
                        "summary": {
                            "lines": {"covered": lines[0], "count": lines[1]},
                            "regions": {"covered": regions[0], "count": regions[1]},
                        },
                    }
                    for name, lines, regions in files
                ]
            }
        ]
    }


class TestPathClassification:

    def test_given_a_tests_directory_when_classifying_then_it_is_a_test_path(self):
        assert coverage.is_test_path("Client/Connection/DataTests/BonjourTests.swift")
        assert coverage.is_test_path("Core/Diff/DomainTests/ParserTests.swift")

    def test_given_shipped_code_when_classifying_then_it_is_not_a_test_path(self):
        assert not coverage.is_test_path("Client/Connection/Data/Bonjour.swift")
        # The suffix must be on a directory, not on the file — a shipped type may be named for tests.
        assert not coverage.is_test_path("Core/Diff/Domain/FixtureTests.swift")

    def test_given_a_view_layer_file_when_classifying_then_it_is_view_code(self):
        assert coverage.is_view_path("Client/Connection/Ui/ServerDiscoveryView.swift")
        assert coverage.is_view_path("Client/App/Presentation/GranitaApp.swift")
        # A layer may hold subdirectories, and they are still that layer.
        assert coverage.is_view_path("Client/Connection/Ui/Components/Badge.swift")

    def test_given_a_domain_or_data_file_when_classifying_then_it_is_not_view_code(self):
        assert not coverage.is_view_path("Core/Diff/Domain/UnifiedDiffParser.swift")
        assert not coverage.is_view_path("Client/Connection/Data/Bonjour.swift")

    def test_given_the_servers_api_when_classifying_then_it_is_not_view_code(self):
        # A presentation layer in the wire sense: domain-to-wire mapping plus routes, with no `Ui`
        # sibling because it has no views. Counting it asks how much of the HTTP router a rendered
        # screen executes, and the answer is always none.
        assert not coverage.is_view_path("Server/Api/Presentation/GranitaRouter.swift")
        assert not coverage.is_view_path("Server/Api/Presentation/Authentication.swift")
        # And the exclusion is that module, not the word "Api" anywhere in a path.
        assert coverage.is_view_path("Client/Api/Presentation/SomeScreen.swift")

    def test_given_a_composition_root_when_classifying_then_no_host_test_reaches_it(self):
        assert not coverage.is_reachable_path("Server/App/Presentation/MacComposition.swift")
        assert not coverage.is_reachable_path("Client/App/Presentation/GranitaMobileScene.swift")
        assert not coverage.is_reachable_path("Server/Cli/Main/GranitaServer.swift")

    def test_given_a_view_body_when_classifying_then_no_host_test_reaches_it(self):
        # Hostless: there is no key window, so a body lays out against nothing and renders blank.
        assert not coverage.is_reachable_path("Server/Mac/Ui/MenuBarContent.swift")

    def test_given_a_composed_screen_when_classifying_then_no_host_test_reaches_it(self):
        # A view body is a view body wherever it lives. `Presentation` holds both models and the
        # screens composed from `Ui`, and only the latter need a renderer.
        assert not coverage.is_reachable_path("Server/Mac/Presentation/GranitaSettingsScreen.swift")
        assert not coverage.is_reachable_path("Client/Connection/Presentation/ServerDiscoveryScreen.swift")
        # The suffix alone does not do it — a domain type may legitimately be named for one.
        assert coverage.is_reachable_path("Client/Viewer/Domain/DiffScreen.swift")

    def test_given_a_keychain_store_when_classifying_then_no_host_test_reaches_it(self):
        # A test binary is unsigned and has no keychain of its own, so the only way to run either of
        # these is to write into a real one. Both halves of the product have one now.
        assert not coverage.is_reachable_path("Server/Identity/Data/KeychainServerIdentityStore.swift")
        assert not coverage.is_reachable_path("Client/Connection/Data/KeychainPairingTokenStore.swift")

    def test_given_a_model_or_a_parser_when_classifying_then_a_host_test_reaches_it(self):
        assert coverage.is_reachable_path("Server/Mac/Presentation/ServerMacModel.swift")
        assert coverage.is_reachable_path("Core/Diff/Domain/UnifiedDiffParser.swift")
        # An App directory that is not a composition root is ordinary code. The pair is what names
        # one, not the word on its own.
        assert coverage.is_reachable_path("Client/App/Domain/Session.swift")
        # Named per file rather than per directory, so what sits beside the Keychain store is still
        # measured — which is the whole reason the exemption is a list of files.
        assert coverage.is_reachable_path("Server/Identity/Data/LocalAddresses.swift")


class TestCollect:

    def test_given_an_export_when_collecting_then_only_package_sources_count(self, tmp_path):
        path = tmp_path / "export.json"
        path.write_text(
            json.dumps(
                export(
                    [
                        ("/w/Packages/Granita/Core/Tree/Domain/Node.swift", (8, 10), (3, 5)),
                        # A test file: ~100% covered by construction, so counting it would mean
                        # writing more test code raises the number regardless of what it reaches.
                        ("/w/Packages/Granita/Core/Tree/DomainTests/NodeTests.swift", (40, 40), (9, 9)),
                        # A dependency, and the package's own generated build products.
                        ("/w/SourcePackages/checkouts/hummingbird/Sources/Router.swift", (1, 99), (1, 40)),
                        ("/w/Packages/Granita/.build/checkouts/x/Sources/X.swift", (1, 99), (1, 40)),
                        # The app shells are thin @main files outside the package.
                        ("/w/Apps/GranitaMobile/GranitaMobileApp.swift", (5, 5), (2, 2)),
                    ]
                )
            )
        )
        out = tmp_path / "summary.json"

        coverage.collect(
            coverage.parse(["collect", "--category", "unit", "--export", str(path), "--out", str(out), "--ref", "main"])
        )

        written = json.loads(out.read_text())
        assert written["categories"]["unit"] == entry((8, 10), (3, 5), scope=coverage.HOST_REACHABLE_SCOPE)

    def test_given_a_summary_when_collecting_another_category_then_both_survive(self, tmp_path):
        out = tmp_path / "summary.json"
        out.write_text(json.dumps(summary({"unit": entry((8, 10), (3, 5))})))
        path = tmp_path / "export.json"
        path.write_text(json.dumps(export([("/w/Packages/Granita/Core/Tree/Ui/Row.swift", (20, 40), (4, 9))])))

        coverage.collect(
            coverage.parse(
                ["collect", "--category", "snapshot", "--export", str(path), "--out", str(out), "--ref", "main"]
            )
        )

        written = json.loads(out.read_text())
        assert written["categories"]["unit"] == entry((8, 10), (3, 5))
        assert written["categories"]["snapshot"] == entry(
            (20, 40), (4, 9), scope=coverage.VIEWS_SCOPE
        )

    def test_given_a_snapshot_export_when_collecting_then_only_view_code_counts(self, tmp_path):
        # A rendered view executes no parser and no repository, so every line of those the app
        # happens to link is one a snapshot can never cover. Left in the denominator, the row falls
        # whenever domain code is added anywhere under the app — which says nothing about snapshots.
        path = tmp_path / "export.json"
        path.write_text(
            json.dumps(
                export(
                    [
                        ("/w/Packages/Granita/Client/Connection/Ui/Discovery.swift", (20, 40), (4, 9)),
                        ("/w/Packages/Granita/Core/Diff/Domain/Parser.swift", (0, 500), (0, 200)),
                        ("/w/Packages/Granita/Client/Connection/Data/Bonjour.swift", (0, 60), (0, 20)),
                    ]
                )
            )
        )
        out = tmp_path / "summary.json"

        coverage.collect(
            coverage.parse(
                ["collect", "--category", "snapshot", "--export", str(path), "--out", str(out), "--ref", "main"]
            )
        )

        written = json.loads(out.read_text())
        assert written["categories"]["snapshot"] == entry(
            (20, 40), (4, 9), scope=coverage.VIEWS_SCOPE
        )

    def test_given_a_unit_export_when_collecting_then_what_a_host_test_cannot_reach_does_not_count(self, tmp_path):
        # A SwiftUI body needs a renderer and a SwiftPM test target is hostless, so a view's lines
        # are uncoverable here by construction. Wiring is the same: nothing depends on a composition
        # root and no test constructs one. Counting either means the number moves when a module is
        # first pulled into a test binary — a fact about the target graph, not about the tests.
        path = tmp_path / "export.json"
        path.write_text(
            json.dumps(
                export(
                    [
                        ("/w/Packages/Granita/Client/Connection/Ui/Discovery.swift", (0, 40), (0, 9)),
                        ("/w/Packages/Granita/Server/App/Presentation/MacComposition.swift", (0, 90), (0, 30)),
                        ("/w/Packages/Granita/Server/Cli/Main/GranitaServer.swift", (0, 190), (0, 60)),
                        # A model in a Presentation module is an ordinary object a test constructs,
                        # so it stays judged — the exclusion is the drawing layer, not the layer above.
                        ("/w/Packages/Granita/Server/Mac/Presentation/ServerMacModel.swift", (20, 25), (6, 8)),
                        ("/w/Packages/Granita/Core/Diff/Domain/Parser.swift", (30, 500), (10, 200)),
                    ]
                )
            )
        )
        out = tmp_path / "summary.json"

        coverage.collect(
            coverage.parse(["collect", "--category", "unit", "--export", str(path), "--out", str(out), "--ref", "main"])
        )

        written = json.loads(out.read_text())
        assert written["categories"]["unit"] == entry((50, 525), (16, 208), scope=coverage.HOST_REACHABLE_SCOPE)

    def test_given_every_configured_scope_when_reading_an_export_then_each_one_narrows(self, tmp_path):
        # The filter selects on the scope *string*, so a scope renamed in one place and not the
        # other stops narrowing anything at all — silently, and in the direction that looks like
        # good news. Asserting the two constants equal each other would be a tautology; this asserts
        # that whatever is configured still removes something.
        path = tmp_path / "export.json"
        path.write_text(
            json.dumps(
                export(
                    [
                        ("/w/Packages/Granita/Client/Connection/Ui/Discovery.swift", (0, 40), (0, 9)),
                        ("/w/Packages/Granita/Core/Diff/Domain/Parser.swift", (30, 500), (10, 200)),
                    ]
                )
            )
        )
        whole = coverage.read_export(path)["lines"]["count"]

        for scope in set(coverage.SCOPES.values()):
            assert coverage.read_export(path, scope)["lines"]["count"] < whole


class TestPercent:

    def test_given_a_counter_when_measuring_then_it_is_a_percentage(self):
        assert coverage.percent(counter(1, 4)) == 25.0

    def test_given_nothing_to_cover_when_measuring_then_it_is_unmeasurable(self):
        # Not the same as 0% and must not read as it: a kind that ran nothing has no grade.
        assert coverage.percent(counter(0, 0)) is None
        assert coverage.percent(None) is None


class TestGate:

    def test_given_every_value_held_when_gating_then_it_passes(self):
        current = summary({"unit": entry((9, 10), (4, 5)), "all": entry((9, 10), (4, 5))})
        baseline = summary({"unit": entry((8, 10), (4, 5)), "all": entry((8, 10), (4, 5))})

        verdict = coverage.gate_verdict(current, baseline)

        assert verdict["status"] == "pass"
        assert len(verdict["checks"]) == 4

    def test_given_lines_held_but_regions_fell_when_gating_then_it_fails(self):
        # The whole point of the second column: a PR can add covered lines while a branch it used
        # to take stops being taken.
        current = summary({"unit": entry((9, 10), (3, 5))})
        baseline = summary({"unit": entry((8, 10), (4, 5))})

        verdict = coverage.gate_verdict(current, baseline)

        assert verdict["status"] == "fail"
        assert [check["label"] for check in verdict["regressions"]] == ["Unit regions"]

    def test_given_a_kind_measured_for_the_first_time_when_gating_then_it_is_not_judged(self):
        current = summary({"unit": entry((8, 10), (4, 5)), "snapshot": entry((1, 10), (1, 5))})
        baseline = summary({"unit": entry((8, 10), (4, 5))})

        verdict = coverage.gate_verdict(current, baseline)

        assert verdict["status"] == "pass"
        assert [check["category"] for check in verdict["checks"]] == ["unit", "unit"]

    def test_given_a_baseline_measured_over_other_files_when_gating_then_it_is_not_judged(self):
        # Changing what a row measures makes the old number the answer to a different question, not
        # a better one. The kind rejoins the ratchet on the next `main` run, as any new kind does.
        current = summary({"snapshot": entry((9, 10), (4, 5), scope="views")})
        baseline = summary({"snapshot": entry((8, 10), (4, 5), scope="package")})

        assert coverage.gate_verdict(current, baseline)["status"] == "skipped"

    def test_given_a_baseline_measured_the_same_way_when_gating_then_it_is_judged(self):
        current = summary({"snapshot": entry((7, 10), (4, 5), scope="views")})
        baseline = summary({"snapshot": entry((8, 10), (4, 5), scope="views")})

        verdict = coverage.gate_verdict(current, baseline)

        assert verdict["status"] == "fail"
        assert [check["label"] for check in verdict["regressions"]] == ["Snapshot lines"]

    def test_given_a_kind_that_ran_nothing_when_gating_then_it_is_not_judged(self):
        current = summary({"ui": entry((0, 0), (0, 0))})
        baseline = summary({"ui": entry((0, 0), (0, 0))})

        assert coverage.gate_verdict(current, baseline)["status"] == "skipped"

    def test_given_no_baseline_when_gating_then_the_gate_is_skipped(self):
        assert coverage.gate_verdict(summary({"unit": entry((8, 10), (4, 5))}), None)["status"] == "skipped"

    def test_given_a_drop_below_the_printed_precision_when_gating_then_it_holds(self):
        # The verdict can never contradict the ±0 in the row above it.
        current = summary({"unit": entry((9999, 100000), (1, 2))})
        baseline = summary({"unit": entry((10000, 100000), (1, 2))})

        assert coverage.gate_verdict(current, baseline)["status"] == "pass"


class TestRender:

    def render(self, tmp_path, current: dict, baseline: dict | None) -> str:
        current_path = tmp_path / "current.json"
        current_path.write_text(json.dumps(current))
        baseline_path = tmp_path / "baseline.json"
        if baseline is not None:
            baseline_path.write_text(json.dumps(baseline))
        out = tmp_path / "comment.md"
        coverage.render(
            coverage.parse(
                [
                    "render",
                    "--current",
                    str(current_path),
                    "--baseline",
                    str(baseline_path),
                    "--out",
                    str(out),
                    "--verdict-out",
                    str(tmp_path / "verdict.json"),
                ]
            )
        )
        return out.read_text()

    def test_given_a_redefined_all_scope_when_rendering_then_no_uncovered_trend_is_claimed(self, tmp_path):
        # The table skips a redefined row and so does the gate. The uncovered-lines line has to skip
        # it too, or it subtracts across two different file sets and reports the redefinition as a
        # change in the code — in the one report whose whole design principle is comparing like
        # with like.
        text = self.render(
            tmp_path,
            summary({"all": entry((80, 100), (40, 50), scope="host-reachable-no-keychain")}),
            summary({"all": entry((90, 100), (45, 50), scope="host-reachable")}),
        )

        assert "**20 uncovered lines** across the project." in text
        assert "than the baseline" not in text

    def test_given_the_same_all_scope_when_rendering_then_the_uncovered_trend_is_reported(self, tmp_path):
        text = self.render(
            tmp_path,
            summary({"all": entry((80, 100), (40, 50), scope="host-reachable")}),
            summary({"all": entry((90, 100), (45, 50), scope="host-reachable")}),
        )

        assert "10 more than the baseline" in text

    def test_given_a_summary_when_rendering_then_every_kind_has_a_row(self, tmp_path):
        text = self.render(tmp_path, summary({"unit": entry((8, 10), (4, 5))}), None)

        for label in ("Unit", "Ui", "Snapshot", "All tests"):
            assert f"| {label}" in text or f"| **{label}**" in text

    def test_given_a_kind_with_no_pass_when_rendering_then_its_cells_are_dashes(self, tmp_path):
        text = self.render(tmp_path, summary({"unit": entry((8, 10), (4, 5))}), None)

        assert "| Ui | — | — |" in text

    def test_given_a_baseline_when_rendering_then_cells_carry_a_delta(self, tmp_path):
        text = self.render(
            tmp_path,
            summary({"unit": entry((9, 10), (4, 5))}),
            summary({"unit": entry((8, 10), (4, 5))}),
        )

        assert "90.0% ▲ +10.0" in text
        assert "80.0% ±0" in text

    def test_given_a_regression_when_rendering_then_the_comment_names_it(self, tmp_path):
        text = self.render(
            tmp_path,
            summary({"unit": entry((7, 10), (4, 5))}),
            summary({"unit": entry((8, 10), (4, 5))}),
        )

        assert "Coverage gate failed" in text
        assert "Unit lines" in text

    def test_given_a_baseline_measured_over_other_files_when_rendering_then_the_row_carries_no_delta(self, tmp_path):
        # The gate refuses to judge such a pair, so the table must not show an arrow for it either:
        # a delta nobody computed reads as a verdict, and here it would read as a large improvement.
        text = self.render(
            tmp_path,
            summary({"snapshot": entry((9, 10), (4, 5), scope="views")}),
            summary({"snapshot": entry((5, 10), (2, 5), scope="package")}),
        )

        assert "| Snapshot | 90.0% (new) | 80.0% (new) |" in text

    def test_given_two_rows_with_different_denominators_when_rendering_then_the_report_says_so(self, tmp_path):
        # Two percentages in one table that are not measured over the same files read as comparable
        # unless the table says otherwise.
        text = self.render(tmp_path, summary({"snapshot": entry((8, 10), (4, 5), scope="views")}), None)

        assert "view layers alone" in text

    def test_given_no_module_breakdown_is_wanted_when_rendering_then_none_is_written(self, tmp_path):
        # Coverage is reported per test kind, not per module: the question worth asking is which
        # kind of test reaches the code, and a per-module table answers a different one.
        text = self.render(tmp_path, summary({"unit": entry((8, 10), (4, 5))}), None)

        assert "Module" not in text
        assert "package" not in text.lower()


class TestEnforce:

    def enforce(self, tmp_path, verdict: dict) -> int:
        path = tmp_path / "verdict.json"
        path.write_text(json.dumps(verdict))
        return coverage.enforce(coverage.parse(["enforce", "--verdict", str(path)]))

    def test_given_a_passing_verdict_when_enforcing_then_it_exits_zero(self, tmp_path):
        assert self.enforce(tmp_path, {"status": "pass", "checks": [], "regressions": []}) == 0

    def test_given_a_skipped_verdict_when_enforcing_then_it_exits_zero(self, tmp_path):
        assert self.enforce(tmp_path, {"status": "skipped", "checks": [], "regressions": []}) == 0

    def test_given_a_failing_verdict_when_enforcing_then_it_exits_one(self, tmp_path):
        verdict = {
            "status": "fail",
            "checks": [],
            "regressions": [{"label": "Unit lines", "current": 70.0, "baseline": 80.0}],
        }

        assert self.enforce(tmp_path, verdict) == 1

    def test_given_no_verdict_at_all_when_enforcing_then_it_exits_one(self, tmp_path):
        # Silence is not consent: a missing verdict means the report step never ran.
        assert coverage.enforce(coverage.parse(["enforce", "--verdict", str(tmp_path / "nope.json")])) == 1
