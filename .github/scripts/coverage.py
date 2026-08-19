#!/usr/bin/env python3
"""Measure, report and gate line coverage.

The gate is Oltre's rule, deliberately: a plain **ratchet** against the last green `main` run, with
no floor and no slack. Every percentage in the table must hold at or above the baseline. A fixed
threshold either sits so low it never fires or so high it blocks unrelated work; a ratchet asks the
only question worth asking of a pull request, which is whether it made things worse.

Three subcommands, matching how CI uses them:

    collect   an llvm-cov export  ->  a small, diffable summary
    render    summary + baseline  ->  a PR comment and a verdict
    enforce   a verdict           ->  exit 1 if coverage regressed

**Test sources are excluded.** A test file is ~100% covered by construction, so counting them means
writing more test code raises the number regardless of what it reaches. The figure here answers
"how much of Granita does the suite exercise", and cannot be gamed.

Coverage is grouped by **module** rather than by directory, because the module is the unit the
architecture is expressed in — `Client/Viewer/Data` is `ClientViewerData` — so a regression names
something a reader can act on.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

# A directory whose name ends in Tests holds tests. That is the repository's own convention
# (`Client/Viewer/DomainTests`), so it needs no separate list to fall out of date.
def is_test_path(relative: str) -> bool:
    return any(part.endswith("Tests") for part in pathlib.PurePosixPath(relative).parts[:-1])


def module_of(relative: str) -> str:
    """`Client/Connection/Domain/Foo.swift` -> `ClientConnectionDomain`.

    Mirrors the manifest: a module's name is its path with the slashes removed.
    """
    parts = pathlib.PurePosixPath(relative).parts
    return "".join(parts[:3]) if len(parts) >= 4 else "".join(parts[:-1])


def empty() -> dict:
    return {"covered": 0, "count": 0}


def add(into: dict, more: dict) -> None:
    into["covered"] += more["covered"]
    into["count"] += more["count"]


def percent(counter: dict | None) -> float | None:
    if not counter or not counter["count"]:
        return None
    return 100.0 * counter["covered"] / counter["count"]


def collect(args: argparse.Namespace) -> int:
    export = json.loads(pathlib.Path(args.export).read_text())
    marker = "/Packages/Granita/"

    totals, modules = empty(), {}
    for entry in export["data"][0]["files"]:
        name = entry["filename"]
        # Anything outside the package is a dependency or a toolchain header, and anything under
        # .build is generated.
        if marker not in name or "/.build/" in name:
            continue
        relative = name.split(marker, 1)[1]
        if is_test_path(relative):
            continue
        lines = {"covered": entry["summary"]["lines"]["covered"], "count": entry["summary"]["lines"]["count"]}
        add(totals, lines)
        add(modules.setdefault(module_of(relative), empty()), lines)

    summary = {
        "ref": args.ref,
        "totals": totals,
        "modules": dict(sorted(modules.items())),
    }
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"lines {totals['covered']}/{totals['count']} ({percent(totals) or 0:.1f}%) across {len(modules)} modules")
    return 0


def format_delta(current: float | None, baseline: float | None) -> str:
    if current is None:
        return "—"
    if baseline is None:
        return f"{current:.1f}%  (new)"
    change = current - baseline
    if abs(change) < 0.05:
        return f"{current:.1f}%  ="
    return f"{current:.1f}%  {'+' if change > 0 else ''}{change:.1f}"


def gate_checks(current: dict, baseline: dict) -> list[dict]:
    """One check per row that exists in BOTH runs.

    A module absent from the baseline is new and has nothing to regress against; a module absent
    from the current run was deleted, and deleting code is not a coverage regression.
    """
    checks = []
    rows = [("total", current["totals"], baseline["totals"])]
    for name, counter in current["modules"].items():
        if name in baseline.get("modules", {}):
            rows.append((name, counter, baseline["modules"][name]))

    for name, now, before in rows:
        now_percent, before_percent = percent(now), percent(before)
        if now_percent is None or before_percent is None:
            continue
        # A hair of tolerance for float formatting only — not slack. Anything a reader would see as
        # a drop in the rendered table is a drop here.
        checks.append({
            "name": name,
            "current": now_percent,
            "baseline": before_percent,
            "ok": now_percent >= before_percent - 0.05,
        })
    return checks


def verdict_for(current: dict, baseline: dict | None) -> dict:
    checks = gate_checks(current, baseline) if baseline else []
    regressions = [c for c in checks if not c["ok"]]
    return {
        "ok": not regressions,
        "compared": baseline is not None,
        "checks": checks,
        "regressions": regressions,
    }


def render(args: argparse.Namespace) -> int:
    current = json.loads(pathlib.Path(args.current).read_text())
    baseline_path = pathlib.Path(args.baseline)
    baseline = json.loads(baseline_path.read_text()) if baseline_path.is_file() else None

    verdict = verdict_for(current, baseline)

    lines = ["<!-- granita-coverage-report -->", "## Coverage", ""]
    if baseline is None:
        lines += ["No baseline yet — the first `main` run records one. Nothing is gated this time.", ""]

    lines += ["| | Lines | Covered |", "|---|---|---|"]
    base_modules = (baseline or {}).get("modules", {})
    lines.append(
        f"| **total** | {format_delta(percent(current['totals']), percent((baseline or {}).get('totals')))} "
        f"| {current['totals']['covered']}/{current['totals']['count']} |"
    )
    for name, counter in current["modules"].items():
        lines.append(
            f"| `{name}` | {format_delta(percent(counter), percent(base_modules.get(name)))} "
            f"| {counter['covered']}/{counter['count']} |"
        )

    lines.append("")
    if verdict["regressions"]:
        lines.append("**Coverage regressed:**")
        lines += [
            f"- `{r['name']}` {r['baseline']:.1f}% → {r['current']:.1f}%"
            for r in verdict["regressions"]
        ]
        lines += ["", "The gate is a ratchet against the last green `main` run: no floor, no slack."]
    elif verdict["compared"]:
        lines.append("No module went backwards against `main`.")

    pathlib.Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(args.out).write_text("\n".join(lines) + "\n")
    pathlib.Path(args.verdict_out).write_text(json.dumps(verdict, indent=2) + "\n")
    print("\n".join(lines))
    return 0


def enforce(args: argparse.Namespace) -> int:
    verdict = json.loads(pathlib.Path(args.verdict).read_text())
    if verdict["ok"]:
        print("Coverage held." if verdict["compared"] else "No baseline to compare against yet.")
        return 0
    for regression in verdict["regressions"]:
        print(
            f"::error::Coverage regressed in {regression['name']}: "
            f"{regression['baseline']:.1f}% → {regression['current']:.1f}%"
        )
    return 1


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("collect", help="llvm-cov export -> summary")
    p.add_argument("--export", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--ref", default="local")
    p.set_defaults(func=collect)

    p = sub.add_parser("render", help="summary + baseline -> comment and verdict")
    p.add_argument("--current", required=True)
    p.add_argument("--baseline", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--verdict-out", required=True)
    p.set_defaults(func=render)

    p = sub.add_parser("enforce", help="verdict -> exit code")
    p.add_argument("--verdict", required=True)
    p.set_defaults(func=enforce)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
