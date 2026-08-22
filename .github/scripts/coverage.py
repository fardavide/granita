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

# The layer a host test cannot execute at all: a SwiftUI view body needs a renderer, and a SwiftPM
# test target is hostless. Distinct from VIEW_LAYERS, which includes `Presentation` — a model there
# is an ordinary object a test constructs, and must stay judged.
DRAWING_LAYER = "Ui"

# The composition roots, by the directory each one occupies. Wiring implementations into protocols
# is their whole job, nothing depends on them, and no test constructs one — `granita-server` has
# never been measured at all, because an executable target is not linked into a test binary. That
# exemption was an accident of packaging rather than a decision; naming the directories makes it
# the same decision for all three.
COMPOSITION_ROOTS = {("App", "Presentation"), ("Cli", "Main")}

# Files a host test cannot execute for a reason that is not a layer and not a composition root.
#
# Both are Keychain stores, and the bar each met is the same: the code must be unrunnable from
# `swift test` *by construction*, not merely untested. A SwiftPM test binary is unsigned and has no
# keychain of its own, so the only way to run either at all is to write into a real one — which is
# why each sits behind a protocol, why everything downstream is tested against a fake, and why the
# Mac's was verified by running the server instead. See `decisions.md` and the "Verified against the
# real environment" section of `status.md`.
#
# Named per file rather than per directory, deliberately: `Server/Identity/Data` also holds the
# interface enumeration and `Client/Connection/Data` holds the whole API client, both of which a
# host test does reach and does cover, and exempting either directory would stop measuring them.
UNREACHABLE_FILES = {
    "Server/Identity/Data/KeychainServerIdentityStore.swift",
    "Client/Connection/Data/KeychainPairingTokenStore.swift",
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
# The scope's name has changed twice, and each rename is the point rather than a tidy-up: the gate
# compares two numbers only when both were taken the same way, so renaming is how a redefinition
# declares itself and leaves these two rows unjudged for exactly one run instead of failing the pull
# request that redefines them. `reachable` became `host-reachable` when UNREACHABLE_FILES was added
# for the Mac's Keychain store, and `host-reachable-no-keychain` when the phone's joined it — the
# name now says what the set actually is rather than leaving one member unmentioned.
#
# The gap this leaves is real and is tracked rather than hidden: a macOS view layer is measured by
# nothing until a macOS snapshot kind exists. See status.md.
DEFAULT_SCOPE = "package"
SCOPES = {
    "snapshot": "views",
    "unit": "host-reachable-no-keychain",
    "all": "host-reachable-no-keychain"
}


# --- collect -----------------------------------------------------------------------------------


def is_test_path(relative: str) -> bool:
    """A directory whose name ends in Tests holds tests.

    That is the repository's own convention (`Client/Viewer/DomainTests`), so it needs no separate
    list to fall out of date. The suffix must be on a directory rather than on the file, because a
    shipped type may legitimately be named for tests.
    """
    return any(part.endswith("Tests") for part in pathlib.PurePosixPath(relative).parts[:-1])


def is_view_path(relative: str) -> bool:
    """A file in a layer that draws — the only code a rendered snapshot can execute."""
    return bool(VIEW_LAYERS.intersection(pathlib.PurePosixPath(relative).parts[:-1]))


def is_composition_root_path(relative: str) -> bool:
    """A file in one of the three composition roots, matched on the pair of directories naming it."""
    parts = pathlib.PurePosixPath(relative).parts[:-1]
    return any(pair in COMPOSITION_ROOTS for pair in zip(parts, parts[1:]))


def is_reachable_path(relative: str) -> bool:
    """A file a host test could execute: not a view body, not wiring nothing depends on, and not
    something whose only real collaborator is absent from a test binary."""
    if DRAWING_LAYER in pathlib.PurePosixPath(relative).parts[:-1]:
        return False
    if relative.lstrip("/") in UNREACHABLE_FILES:
        return False
    return not is_composition_root_path(relative)


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
        if scope == "views" and not is_view_path(relative):
            continue
        if scope == "host-reachable" and not is_reachable_path(relative):
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
    base_missed = uncovered_lines(baseline) if has_baseline else None
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
