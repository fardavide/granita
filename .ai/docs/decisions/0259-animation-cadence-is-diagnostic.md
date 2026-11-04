# Animation cadence is diagnostic

Davide asks to remove the animation test after repeated CI motion failures. The narrow change
removes three cadence assertions from the existing native interaction suite:

- Collapse no longer requires at least three intermediate viewport frames.
- Collapse no longer caps one observed step at a quarter of its total travel.
- File selection no longer requires observing movement while the native scroll-animation flag is active.

The measurements and attachments remain diagnostic. The selector test is renamed to describe its
remaining contract: reaching the requested header. Every original fixture still executes.

Final model/presentation offsets, the requested file's identity and reading state, native header
alignment and descendant geometry, arrival coherence, and exact selected-header images remain
asserted. Existing setup and completion deadlines remain; these still detect an operation that
does not finish. The app's animations, production source, snapshot baselines, coverage scopes and
numeric ratchets are unchanged.

This deliberately supersedes the earlier requirement to preserve all motion assertions in this
repair. It removes cadence from the CI contract; it does not establish that rendering stalls or
visible stutter are repaired. A transition with poor cadence can now pass these cases if its
remaining correctness checks pass.

The pending separate CPU-profile publication proposal is superseded. Local `make test`, `make build`
and `make resolve` pass; the lockfile retains all 30 pins without changes. All 67 iOS interaction
executions across 18 functions pass, with no skips or structured runtime warnings, in
`/private/tmp/granita-cadence-diagnostic-interactions-20261104-a.xcresult`. No production source or
generated project file changes. The existing 0.23.1 release notes are corrected to disclose the
remaining stutter. Remote CI and aggregate coverage remain unverified until the separately
approved publication completes. Previous conditional PR wording promising unchanged motion limits
or a complete animation repair is superseded and must not be applied. Davide approves one commit,
`Keep reader animation cadence diagnostic`, and one push. The newly reviewed replacement PR
wording may be applied only after all seven required checks pass. Merge approval remains separate.

The approved commit is published as `4de7b33`. [CI 395](https://github.com/fardavide/granita/actions/runs/41836381909)
passes 580 of 581 group-1 executions. Its sole failure is a retained source-reopen correctness
check: the `.viewed` case finds no visible final header after its settlement helper returns.
Both builds, package tests, generated files, Mac snapshots and group 0 pass. Coverage stops on
the failed suite, before producing numbers. This is not a green CI result and does not authorize
another commit, push, retry or merge. The reviewed replacement PR wording remains unapplied.

A local native control establishes a narrower test-helper defect. It uses the same three-file
source-reopen fixture and delays native host presentation with a two-second UIKit reveal, inside
the existing three-second completion budget. The unchanged helper reports settlement with quiet
scroll geometry while the host's presentation opacity is only 0.37028176. Its final visible-header
count is zero. All 67 existing interaction executions pass; only this new readiness control fails:
`/private/tmp/granita-header-readiness-red-20261104-b.xcresult`. An earlier incorrectly quoted filter
executes zero cases and is explicitly not a RED result.

The local helper candidate additionally waits for one visible native header, using the existing
opacity and viewport predicate. Reopen observation, five quiet frames, the three-second deadline,
and all final position and image assertions remain. All 68 expanded interaction executions across
19 functions then pass, with zero skips or structured runtime warnings:
`/private/tmp/granita-header-readiness-green-20261104-a.xcresult`. Console UIKit and package warnings
remain. No app source or baseline changes. This proves the helper can return prematurely and that
the local candidate handles delayed presentation; it does not establish that opacity caused the
remote failure.

Broader local verification passes the complete instrumented iOS groups (589 + 582 executions),
all 22 touch/native-input executions, the package suite with fresh coverage, both unsigned app
builds and dependency resolution. Native summaries report zero failures, skips or structured
runtime warnings. Unit, both iOS and Ui manifests share working-copy source digest
`3726ac8993491737938826c20ceab4e3c2d174714b06c17d50aded752564db0b` on parent `4de7b33`.
The combined coverage command validates the available inputs, then exits at the missing
`build/coverage-inputs/mac/manifest.json`, before any numerical verdict. No Mac desktop tests run.
The lockfile retains all 30 pins unchanged; only this decision, status and the interaction-test
file differ from the published head. Fresh source review finds no blocker. Remote validation,
aggregate coverage and TestFlight delivery remain unverified for this candidate. Davide approves
one commit, `Wait for reopened headers before checking snapshots`, and one push of these three
files to run all seven required checks. Another publication requires a new review; merge stays
separate.
