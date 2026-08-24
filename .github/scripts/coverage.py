#!/usr/bin/env python3
"""Measure, report and gate coverage **per kind of test**.

The report answers one question the whole-suite number cannot: *which kind of test is actually
reaching this code*. A row per kind — unit, ui, snapshot, and everything together — and two columns
per row.

Three subcommands, matching how CI uses them:

    collect   one llvm-cov export  ->  one row of a small, diffable summary
    render    summary + baseline   ->  a PR comment and a verdict
    enforce   a verdict            ->  exit 1 if coverage regressed

**Lines and regions, not lines and branches.** swiftc emits no branch coverage: llvm-cov reports
`branches: 0/0` across every mapped line in this project, dependencies included, and there is no
flag that changes it — the counter exists for clang. `regions` is what Swift does emit and is the
near-equivalent: an `if`, a `guard`, each `case`, a ternary and every closure body get their own
counter, so a region number moves when a path stops being taken even though the line total holds.

**Test sources are excluded.** A test file is ~100% covered by construction, so counting them means
writing more test code raises the number regardless of what it reaches. The figure here answers
"how much of Granita does this kind of test exercise", and cannot be gamed.

The gate is Oltre's rule: a plain **ratchet** against the last green `main` run, with no floor and
no slack. Every percentage in the table must hold at or above the baseline. A fixed threshold either
sits so low it never fires or so high it blocks unrelated work; a ratchet asks the only question
worth asking of a pull request, which is whether it made things worse.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys

# Order is the report's order, and "all" is last because it is the summary line.
CATEGORIES = ["unit", "ui", "snapshot", "all"]

LABELS = {
    "unit": "Unit",
    "ui": "Ui",
    "snapshot": "Snapshot",
    "all": "All tests",
}

# The two llvm-cov counters the table shows and the gate judges. The export carries `functions`,
# `instantiations` and `mcdc` as well: the first two move with refactors rather than with tests,
# and mcdc is 0/0 for the same reason branches are.
COUNTERS = ["lines", "regions"]

COMMENT_MARKER = "<!-- granita-coverage-report -->"

# The gate judges to the precision the table prints. Without this a 0.01-point drop would fail a
# pull request whose own report shows the delta as "±0" — the same tolerance `format_delta` uses to
# decide a number has not moved, so the verdict can never contradict the row above it.
GATE_EPSILON = 0.05

# Only the package is measured. The two Xcode targets are thin `@main` shells with nothing testable
# in them, and everything else in an export is a dependency or a toolchain header.
PACKAGE_MARKER = "/Packages/Granita/"

# The two layers that draw. A layer may hold subdirectories, so the name is matched anywhere in the
# path rather than only at the position the convention usually puts it.
VIEW_LAYERS = {"Ui", "Presentation"}

# The one Presentation module that presents no views.
#
# `Server/Api/Presentation` is a presentation layer in the wire sense — domain-to-wire mapping plus
# routes — and architecture.md says so in as many words: "It has no `Ui` sibling because it has no
# views." Selecting the views scope on the directory name alone therefore swept in the HTTP router,
# the authenticator, the pairing and the registry, which no rendered screen can ever execute.
#
# It went unnoticed while only the phone had a snapshot kind, because the simulator never linked
# these files and an export cannot include what a binary does not map. The macOS kind links them,
# and they arrived as **1199 of the views scope's 2350 lines** — more than half the denominator,
# `GranitaRouter.swift` alone contributing 562. A row measured that way answers "how much of the
# HTTP API does a rendered screen execute", which is a question with one correct answer: none.
NON_DRAWING_PRESENTATION = ("Server", "Api", "Presentation")

# A SwiftUI `View` that lives in `Presentation` rather than `Ui`.
#
# `Presentation` composes screens out of `Ui`'s stateless views, so a handful of its files are view
# bodies and the rest are models. A body needs a renderer and a SwiftPM test target is hostless, so
# these are uncoverable by a host test for exactly the reason `Ui` is — the layer exclusion below
# was simply the incomplete spelling of that rule, and it went unnoticed while the only such file
# was `ServerDiscoveryScreen.swift` at 23 lines. `GranitaSettingsScreen.swift` is 101, all of them
# uncovered, and it is what made the incompleteness visible.
#
# Matched on the project's own naming: a composed screen is named `…Screen`. Models are not, and
# stay judged — `ServerMacModel` is an ordinary object a test constructs.
SCREEN_SUFFIX = "Screen.swift"

# The layer a host test cannot execute at all: a SwiftUI view body needs a renderer, and a SwiftPM
# test target is hostless. Distinct from VIEW_LAYERS, which includes `Presentation` — a model there
# is an ordinary object a test constructs, and must stay judged.
DRAWING_LAYER = "Ui"

# The layer the composition roots occupy. Wiring implementations into protocols is their whole job,
# nothing depends on them, and no test constructs one — `granita-server` has never been measured at
# all, because an executable target is not linked into a test binary. That exemption was an accident
# of packaging rather than a decision.
#
# It used to be a set of directory *pairs*, `{("App", "Presentation"), ("Cli", "Main")}`, because two
# of the three roots were filed under a layer they were not: a module called `Presentation` that a
# rendered baseline cannot draw and a host test cannot construct is a module both scopes have to
# carry a clause about. Both scopes carried one, and both clauses were the same fact spelled twice.
#
# The roots are now the `Main` layer — `Client/App/Main`, `Server/App/Main`, `Server/Cli/Main` — so
# this is a layer name matched exactly the way `Ui` is, and the views scope needs no clause at all:
# `Main` is neither `Ui` nor `Presentation`, so nothing in a root selects into it in the first place.
COMPOSITION_ROOT_LAYER = "Main"

# Files a host test cannot execute for a reason that is not a layer and not a composition root.
#
# The bar each one met is the same, and it is deliberately high: the code must be unrunnable from
# `swift test` *by construction*, not merely untested. Two are Keychain stores — a SwiftPM test
# binary is unsigned and has no keychain of its own, so the only way to run either at all is to write
# into a real one, which is why each sits behind a protocol, why everything downstream is tested
# against a fake, and why the Mac's was verified by running the server instead.
#
# The third is the login item, and it meets the same bar for the same shape of reason. Every line of
# it goes through `SMAppService.mainApp`, which is the *running main bundle* — in a test process that
# is the unsigned test runner, so `register()` would either fail for want of a signature or write the
# test binary into the developer's real Login Items. There is no version of running this that is not
# a side effect on the machine.
#
# Named per file rather than per directory, deliberately: `Server/Identity/Data` also holds the
# interface enumeration, `Client/Connection/Data` holds the whole API client, and `Server/Mac/Data`
# holds the git probe — all three a host test does reach and does cover, and exempting any of those
# directories would stop measuring them.
UNREACHABLE_FILES = {
    "Server/Identity/Data/KeychainServerIdentityStore.swift",
    "Client/Connection/Data/KeychainPairingTokenStore.swift",
    "Server/Mac/Data/ServiceLoginItemRegistry.swift",
    # Every line is a call on the *running application* — `NSApp`, `NSPasteboard`, `NSWorkspace`, and
    # a modal panel whose `runModal()` would not return in a test process at all. Stronger than the
    # three above it, which merely fail: this one hangs.
    #
    # It entered this scope by being *moved into it*, which is the fact that justifies the
    # exemption rather than the arithmetic. These calls used to sit in `GranitaSettingsScreen`,
    # which this scope already excluded as a body; taking them out of a view — the right change, and
    # the one that made three of them assertable for the first time — carried unrunnable code into a
    # module that is judged. The pane spellings stayed behind in `SystemSettingsPaneUrl.swift`
    # precisely so the part that *is* a pure function keeps being measured.
    "Server/Mac/Data/AppKitSystemGestures.swift",
}

# What each kind's percentage is measured over, and the name that says so in the summary.
#
# The snapshot kind is scoped to the view layers because a rendered view executes no repository and
# no parser: every line of those that the phone app happens to link is one a snapshot can never
# cover. Measured over the whole package, the row falls whenever domain code is added anywhere under
# the app — which is a fact about the app's dependency graph and not about the snapshots. Scoped, it
# answers the question it exists for: of the code that draws screens, how much does a baseline put
# on screen.
#
# The Ui kind is deliberately left unscoped. A behavioural test drives the real app, so reaching a
# repository and a parser is exactly what it does, and scoping it would undercount it.
#
# The unit and all-tests kinds are scoped to what a test can reach. A host `swift test` cannot
# render a SwiftUI body, cannot construct a composition root, and has no keychain to write to, so
# those lines are uncoverable by construction rather than uncovered by neglect — and counting them
# means the number moves when a module is first pulled into a test binary, which is a fact about the
# target graph rather than about the tests. Drawing code is judged by the Snapshot row instead,
# which is the mirror of this rule: that row excludes everything a rendered view cannot execute.
#
# The scope's name has changed three times, and each rename is the point rather than a tidy-up: the
# gate
# compares two numbers only when both were taken the same way, so renaming is how a redefinition
# declares itself and leaves these two rows unjudged for exactly one run instead of failing the pull
# request that redefines them. `reachable` became `host-reachable` when UNREACHABLE_FILES was added
# for the Mac's Keychain store, and `host-reachable-no-keychain` when the phone's joined it — the
# name now says what the set actually is rather than leaving one member unmentioned.
#
# Both names moved again when the macOS snapshot kind arrived, and both times because that kind
# exposed a definition which had only ever been exercised on one platform. `views` became
# `views-drawing-only`, because the server's API module is a `Presentation` that draws nothing and
# had been invisible only while no binary linked it into a snapshot pass. `host-reachable-no-keychain`
# became `…-no-screens`, because a SwiftUI body is uncoverable by a host test wherever it lives and
# excluding only `Ui` was the incomplete spelling of that.
#
# **Neither correction flatters a number, which is the test worth applying to any rescoping.** With
# the screens removed and nothing else changed, the Unit row reads 95.5% against the 93.9% baseline
# it had been failing — higher, not lower. Lines that leave a denominator and take the percentage
# *up* were dragging it down by being unreachable, not by being untested.
#
# `…-no-keychain-…` became `…-no-system-services-…` when the login item joined the set, and that one
# needs its own justification because it *does* raise the number and it was added by the very pull
# request it unblocked. The bar is the one above and not the arithmetic: `ServiceLoginItemRegistry`
# is every line a call on `SMAppService.mainApp`, which in a test process is the unsigned test
# runner, so running it means writing the test binary into the developer's real Login Items. It had
# been invisible rather than judged — nothing in the package linked `Server/Mac/Data` until that
# module got a test target — so this is a definition catching up with a module that had just entered
# the scope, which is the same story as the two before it.
#
# The two narrowing scopes are named constants rather than repeated literals, and that is not
# tidiness: the filter below selects on this exact string, so a rename spelled in one place and not
# the other stops narrowing anything at all — silently, and in the direction that looks like good
# news. That is precisely what happened the first time this was renamed, and the script's own tests
# are what said so.
# The fifth rename is the first that changes no predicate at all, and it is here because the gate's
# un-judging mechanism is the only one there is: what moved is *how the number is taken*, not which
# files it is taken over. The package pass runs serially now. Measured on 24 August 2026 over five
# parallel runs of one commit, this row came back 96.121% twice and 96.037% three times, and an
# earlier set moved `SessionTranscript` by five lines and `BonjourBrowser` by four — a plain ratchet
# with no slack cannot tell that from a regression, and it did not: #35 failed on a sample and passed
# on a re-run of the same commit. Serially, five runs of one commit agree to the line.
#
# It does not flatter the number, which is the test the four renames above are held to: the row reads
# 95.978% where the parallel sample it replaces read up to 96.121%. What is lost is coverage that was
# never the tests' to claim — lines a scheduler reached before something was torn down.
DEFAULT_SCOPE = "package"
VIEWS_SCOPE = "views-and-screens-only"
HOST_REACHABLE_SCOPE = "host-reachable-no-system-services-no-screens-no-appkit-serial"
SCOPES = {"snapshot": VIEWS_SCOPE, "unit": HOST_REACHABLE_SCOPE, "all": HOST_REACHABLE_SCOPE}


# --- collect -----------------------------------------------------------------------------------


def is_test_path(relative: str) -> bool:
    """A directory whose name ends in Tests holds tests.

    That is the repository's own convention (`Client/Viewer/DomainTests`), so it needs no separate
    list to fall out of date. The suffix must be on a directory rather than on the file, because a
    shipped type may legitimately be named for tests.
    """
    return any(part.endswith("Tests") for part in pathlib.PurePosixPath(relative).parts[:-1])


def is_view_path(relative: str) -> bool:
    """A file in a layer that draws — the only code a rendered snapshot can execute.

    A `Ui` module, plus the screens that compose one. **Not everything filed under `Presentation`**,
    and that correction is the mirror of the one `is_reachable_path` already makes: that scope
    excludes screens because a host test cannot render a body, and this one excludes what is not a
    body because a rendered baseline cannot drive an object. `Presentation` holds three kinds of
    thing — models, the screens composed from `Ui`, and composition roots — and only the middle one
    is code a picture executes.

    Measured before it was changed, on 23 August 2026: the denominator held `ServerMacModel` at 163
    uncovered lines of 241, `KeychainBackedServerHost` at 18 of 117, and `MacComposition` — a
    composition root — at 9 of 97. A row asking "of the code that draws screens, how much does a
    baseline put on screen" was being handed a server host and a wiring module.

    The server's API module needs no clause of its own any more: it has no screens and no `Ui`, so
    nothing in it selects. Neither do the composition roots, since they became the `Main` layer —
    the clause that used to exclude them was only ever needed because two of them were filed under
    `Presentation`, and a `…Screen.swift` in a root would have selected on the name alone.
    """
    parts = pathlib.PurePosixPath(relative).parts[:-1]
    if DRAWING_LAYER in parts:
        return True
    return is_screen_path(relative)


def is_screen_path(relative: str) -> bool:
    """A composed screen: a SwiftUI view body that happens to live in `Presentation`."""
    parts = pathlib.PurePosixPath(relative).parts
    return parts[-1].endswith(SCREEN_SUFFIX) and "Presentation" in parts[:-1]


def is_composition_root_path(relative: str) -> bool:
    """A file in one of the three composition roots, which is to say in the `Main` layer."""
    return COMPOSITION_ROOT_LAYER in pathlib.PurePosixPath(relative).parts[:-1]


def is_reachable_path(relative: str) -> bool:
    """A file a host test could execute: not a view body, not wiring nothing depends on, and not
    something whose only real collaborator is absent from a test binary."""
    parts = pathlib.PurePosixPath(relative).parts[:-1]
    if DRAWING_LAYER in parts or COMPOSITION_ROOT_LAYER in parts:
        return False
    if is_screen_path(relative):
        return False
    return relative.lstrip("/") not in UNREACHABLE_FILES


def empty() -> dict:
    return {"covered": 0, "count": 0}


def read_export(path: pathlib.Path, scope: str = DEFAULT_SCOPE) -> dict:
    """Sum one llvm-cov export down to one counter per kind, over shipped package sources only.

    SwiftPM writes this format itself and `xcrun llvm-cov export` writes the same one, so a host
    `swift test` pass and a simulator `xcodebuild test` pass fold in through the same code.
    """
    export = json.loads(path.read_text())
    totals = {counter: empty() for counter in COUNTERS}
    for entry in export["data"][0]["files"]:
        name = entry["filename"]
        # `.build` holds resolved dependencies and generated sources, both of which sit under the
        # package marker and neither of which is ours.
        if PACKAGE_MARKER not in name or "/.build/" in name:
            continue
        relative = name.split(PACKAGE_MARKER, 1)[1]
        if is_test_path(relative):
            continue
        if scope == VIEWS_SCOPE and not is_view_path(relative):
            continue
        if scope == HOST_REACHABLE_SCOPE and not is_reachable_path(relative):
            continue
        for counter in COUNTERS:
            measured = entry["summary"].get(counter)
            if not measured:
                continue
            totals[counter]["covered"] += measured["covered"]
            totals[counter]["count"] += measured["count"]
    return totals


def collect(args: argparse.Namespace) -> int:
    out = pathlib.Path(args.out)
    summary = json.loads(out.read_text()) if out.is_file() else {"categories": {}}

    scope = SCOPES.get(args.category, DEFAULT_SCOPE)
    # Recorded beside the counters so the gate can tell a number that got worse from a number that
    # started answering a different question.
    summary.setdefault("categories", {})[args.category] = {
        **read_export(pathlib.Path(args.export), scope),
        "scope": scope,
    }
    if args.ref:
        summary["ref"] = args.ref
    if args.commit:
        summary["commit"] = args.commit

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    measured = summary["categories"][args.category]
    print(
        f"{args.category}: lines {show(percent(measured['lines']))}, "
        f"regions {show(percent(measured['regions']))}"
    )
    return 0


# --- render ------------------------------------------------------------------------------------


def percent(counter: dict | None) -> float | None:
    """None when there is nothing to cover — which is not the same as 0% and must not read as it.

    A kind with no test of its own ran nothing and covered nothing; that is a dash, not a failing
    grade, and the gate leaves it alone rather than comparing it to a zero nobody measured.
    """
    if not counter or not counter["count"]:
        return None
    return 100.0 * counter["covered"] / counter["count"]


def show(value: float | None) -> str:
    return "n/a" if value is None else f"{value:.1f}%"


def format_delta(current: float, baseline: float | None) -> str:
    if baseline is None:
        return " (new)"
    change = current - baseline
    if abs(change) < GATE_EPSILON:
        return " ±0"
    return f" {'▲' if change > 0 else '▼'} {change:+.1f}"


def format_cell(counter: dict | None, base_counter: dict | None) -> str:
    value = percent(counter)
    if value is None:
        return "—"
    return f"{value:.1f}%{format_delta(value, percent(base_counter))}"


def category_rows(current: dict, baseline: dict) -> list[str]:
    """Every kind gets a row, including one that ran nothing.

    A kind that is missing from the table is a kind nobody remembers is missing; a row of dashes
    says the project has no test of that kind yet, which is the more useful fact.
    """
    rows = []
    for name in CATEGORIES:
        measured = current.get("categories", {}).get(name, {})
        base = baseline.get("categories", {}).get(name, {})
        # A delta against a number taken over different files is a subtraction nobody performed, and
        # an arrow next to it reads as a verdict. The gate already refuses to judge such a pair; the
        # table has to say the same thing, so the row reads as new rather than as improved.
        if base.get("scope", DEFAULT_SCOPE) != measured.get("scope", DEFAULT_SCOPE):
            base = {}
        emphasis = "**" if name == "all" else ""
        cells = [
            f"{emphasis}{format_cell(measured.get(counter), base.get(counter))}{emphasis}"
            for counter in COUNTERS
        ]
        rows.append(f"| {emphasis}{LABELS[name]}{emphasis} | " + " | ".join(cells) + " |")
    return rows


def uncovered_lines(summary: dict) -> int | None:
    counter = summary.get("categories", {}).get("all", {}).get("lines")
    if not counter or not counter["count"]:
        return None
    return counter["count"] - counter["covered"]


def comparable(current: dict, baseline: dict, category: str) -> bool:
    """Whether two runs measured that kind over the same files.

    The gate asks this before judging a row. Anything that puts two runs' numbers side by side has
    to ask it too, or it reports the redefinition as a change in the code.
    """
    def scope(summary: dict) -> str:
        return summary.get("categories", {}).get(category, {}).get("scope", DEFAULT_SCOPE)

    return scope(current) == scope(baseline)


# --- gate --------------------------------------------------------------------------------------


def gate_checks(current: dict, baseline: dict) -> list[dict]:
    """One entry per table value that both runs put a number on.

    A value only one side has is not a regression and not a pass — it is unjudgeable, and left out
    entirely. A kind measured for the first time joins the ratchet on the next `main` run.

    So is a value the two runs measured over different files. Changing what a row covers makes the
    old number the answer to a different question rather than a better one, and comparing the two
    would fail a pull request for the redefinition itself. Such a kind rejoins the ratchet on the
    next `main` run, exactly as a new one does.
    """
    checks = []
    for category in CATEGORIES:
        measured = current.get("categories", {}).get(category, {})
        base = baseline.get("categories", {}).get(category, {})
        if measured.get("scope", DEFAULT_SCOPE) != base.get("scope", DEFAULT_SCOPE):
            continue
        for counter in COUNTERS:
            now, before = percent(measured.get(counter)), percent(base.get(counter))
            if now is None or before is None:
                continue
            checks.append({
                "category": category,
                "counter": counter,
                "label": f"{LABELS[category]} {counter}",
                "current": now,
                "baseline": before,
                "status": "pass" if now >= before - GATE_EPSILON else "fail",
            })
    return checks


def gate_verdict(current: dict, baseline: dict | None) -> dict:
    checks = gate_checks(current, baseline) if baseline is not None else []
    regressions = [check for check in checks if check["status"] == "fail"]
    if not checks:
        status = "skipped"
    elif regressions:
        status = "fail"
    else:
        status = "pass"
    return {"status": status, "checks": checks, "regressions": regressions}


def values(count: int) -> str:
    return "1 value" if count == 1 else f"{count} values"


def verdict_sentence(verdict: dict) -> str:
    """What the comment leads with — the only part of the report anyone has to act on."""
    if verdict["status"] == "skipped":
        # Almost always a cache miss. It also covers the case where a baseline exists but shares no
        # value with this run, which is why the sentence does not promise which one it was.
        return (
            "⚠️ **The coverage gate did not run** — nothing in this run has a `main` baseline to "
            "compare against, so nothing was enforced."
        )
    if verdict["status"] == "pass":
        return (
            f"✅ **Coverage gate passed** — all {values(len(verdict['checks']))} in the table hold "
            f"at or above the last `main` run."
        )
    return "\n".join([
        f"❌ **Coverage gate failed** — {values(len(verdict['regressions']))} fell below the last "
        f"`main` run:",
        "",
        *[
            f"- **{check['label']}**: {check['current']:.1f}%, below the {check['baseline']:.1f}% "
            f"it held on `main`."
            for check in verdict["regressions"]
        ],
        "",
        "Cover what this branch added. No number in the table may go down, whatever the others do.",
    ])


def render(args: argparse.Namespace) -> int:
    current = json.loads(pathlib.Path(args.current).read_text())
    baseline_path = pathlib.Path(args.baseline) if args.baseline else None
    has_baseline = baseline_path is not None and baseline_path.is_file()
    baseline = json.loads(baseline_path.read_text()) if has_baseline else {}

    lines = [
        COMMENT_MARKER,
        "### Test coverage",
        "",
        "| Test kind | Lines | Regions |",
        "|---|---|---|",
        *category_rows(current, baseline),
        "",
    ]

    # Directly under the table, because it is the one line that can cost someone a merge.
    verdict = gate_verdict(current, baseline if has_baseline else None)
    lines += [verdict_sentence(verdict), ""]

    missed = uncovered_lines(current)
    # Only against a baseline that counted the same files. Everything else in this report compares
    # like with like — the table skips a redefined row and so does the gate — and this line was the
    # one place that did not, so a run which changed what `all` measures printed a subtraction
    # across two different file sets and called it a trend.
    base_missed = uncovered_lines(baseline) if has_baseline and comparable(current, baseline, "all") else None
    if missed is not None:
        # Spelled out rather than arrowed: fewer uncovered lines is the good direction, and a "▼"
        # next to a number reads as a regression however it is meant.
        if base_missed is None or base_missed == missed:
            trend = "."
        elif missed < base_missed:
            trend = f" — {base_missed - missed} fewer than the baseline."
        else:
            trend = f" — {missed - base_missed} more than the baseline."
        lines += [f"**{missed} uncovered lines** across the project{trend}", ""]

    if has_baseline:
        lines.append(f"Δ against `{baseline.get('ref', 'main')}` @ `{baseline.get('commit', 'unknown')[:7]}`.")
    else:
        lines.append("_No baseline yet — deltas appear once this workflow has run on `main`._")
    lines += [
        "",
        "<sub>No number in the table may fall below the last `main` run — every row, not just the "
        "total. Regions rather than branches because swiftc emits no branch coverage; a region is "
        "an `if`, a `guard`, a `case`, a ternary or a closure body. The Snapshot row is measured "
        "over the view layers alone, because a rendered view executes no repository and no parser; "
        "the Unit and All rows are measured over what a host test can reach, which excludes view "
        "bodies and the composition roots. Kinds are directories; see the `swift-testing` "
        "skill.</sub>",
    ]

    text = "\n".join(lines) + "\n"
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text)
    print(text)

    # Written rather than returned as an exit code: the comment has to reach the pull request
    # before the gate closes, so `enforce` is a separate step that runs after it.
    if args.verdict_out:
        verdict_out = pathlib.Path(args.verdict_out)
        verdict_out.parent.mkdir(parents=True, exist_ok=True)
        verdict_out.write_text(json.dumps(verdict, indent=2, sort_keys=True) + "\n")
    return 0


# --- enforce -----------------------------------------------------------------------------------


def enforce(args: argparse.Namespace) -> int:
    path = pathlib.Path(args.verdict)
    if not path.is_file():
        # No verdict means `render` never ran. Silence is not consent.
        print(f"::error::No verdict at {path} — the report step did not run.")
        return 1

    verdict = json.loads(path.read_text())
    status = verdict.get("status")
    if status == "fail":
        for check in verdict["regressions"]:
            print(
                f"::error::Coverage regressed in {check['label']}: "
                f"{check['baseline']:.1f}% → {check['current']:.1f}%"
            )
        return 1
    if status == "skipped":
        print("Coverage gate skipped: nothing in this run has a baseline to compare against.")
        return 0
    print(f"Coverage gate passed: all {len(verdict['checks'])} values hold.")
    return 0


# --- entry point -------------------------------------------------------------------------------


def parse(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    collect_parser = sub.add_parser("collect", help="fold one kind's llvm-cov export into the summary")
    collect_parser.add_argument("--category", required=True, choices=CATEGORIES)
    collect_parser.add_argument("--export", required=True)
    collect_parser.add_argument("--out", required=True)
    collect_parser.add_argument("--ref", default="")
    collect_parser.add_argument("--commit", default=os.environ.get("GITHUB_SHA", ""))
    collect_parser.set_defaults(func=collect)

    render_parser = sub.add_parser("render", help="write the Markdown report and the verdict")
    render_parser.add_argument("--current", required=True)
    render_parser.add_argument("--baseline")
    render_parser.add_argument("--out", required=True)
    render_parser.add_argument("--verdict-out")
    render_parser.set_defaults(func=render)

    enforce_parser = sub.add_parser("enforce", help="exit non-zero if the gate failed")
    enforce_parser.add_argument("--verdict", required=True)
    enforce_parser.set_defaults(func=enforce)

    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
