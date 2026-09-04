---
name: swift-testing
description: Granita's test conventions — Swift Testing not XCTest, the Scenario fixture, given/when/then names, handwritten fakes over mocking frameworks, the golden diff corpus, the snapshot suites and their tolerances, and covering new code against the coverage gate.
when_to_use: >
  Use when writing or reviewing test code — adding a @Test, building a Scenario, writing a fake,
  asserting against a golden fixture, adding or re-recording a snapshot baseline, or when a coverage
  row falls. Also when the user asks to "write a test", "add a fake", "test the parser", "record
  snapshots", or asks why CI's coverage check is red.
---

# Testing

The global `tdd` skill owns the red-green-refactor loop and the global `test-doubles` and
`scenario-pattern` skills own the cross-language rationale. This one owns the Swift shape and what
is specific to Granita.

TDD is not optional here. The diff parser and the git layer are written test first, no exceptions —
they are the two places where a wrong assumption is invisible until a diff renders wrongly on a
phone.

This file is the rules. The evidence behind them — measured numbers, per-fixture facts, and the
approaches that were tried and rejected — lives beside it. Read the reference before overriding the
rule it supports.

- Fixture-by-fixture contents of the diff corpus, and the repositories under `.fixtures/`: see
  [references/golden-fixtures.md](references/golden-fixtures.md)
- Snapshot tolerance values, the drift measurements, and the recording procedure per platform: see
  [references/snapshots.md](references/snapshots.md)
- What each coverage row is measured over, and the recorded redefinitions: see
  [references/coverage-report.md](references/coverage-report.md)

## Framework — Swift Testing, never XCTest

`import Testing`, `@Test`, `#expect`, `#require`. No XCTest anywhere.

Package tests run on the host with no simulator, which is what keeps the loop fast:

```bash
make test
```

## Structure — `// given` / `// when` / `// then`

Each marker appears at most once, in order. When construction itself is the action, use
`// given - when`; when asserting only on state produced by init, omit `// when`.

Name each `@Test` as a `given … when … then …` sentence using a backtick raw identifier, mirroring
the body markers. `given` is optional when there is no precondition.

```swift
@Test func `given a rename when parsing numstat then old and new are not swapped`() { … }
@Test func `when the hunk header omits counts then both default to one`() { … }
```

Group with `// MARK:`.

## Scenario fixture

Each test type uses a `private struct Scenario` that builds the subject from fakes, declared at the
**bottom** of the type, after the tests. Each test makes a fresh one in its body; there is no global
setup.

Constructor parameters are higher-level model values — a list of worktrees, an error to throw —
never fake instances. Expose a fake as a `let` only when a test inspects it; otherwise build it
inline in the subject's init. Do not hoist test data to type or `static` level: each test owns its
data in its `// given`.

## Handwritten fakes, never a mocking framework

There is no mocking framework and we are not adding one. Every double is a `FakeXxx` named after the
protocol it implements — never `Stub-`, `Mock-`, `No-` or `Empty-` — configurable through its
initialiser, with invocation tracking added only when a test asserts on it.

One configurable fake per collaborator, not a family of variants. A fake lives in its own file, never
inline in a test file.

## Assert on distinct, meaningful values

Use values that fail loudly if the wrong thing flows through, not defaults or placeholders. A
rename test whose old and new paths are both `file.txt` asserts nothing about the field order that
the spec warns is inverted between two git commands.

**Never call a production mapper inside an assertion.** Compare against a pre-built expected value,
so the test catches mapper bugs instead of mirroring them.

## The golden diff corpus

`Packages/Granita/Core/Diff/DomainTests/Fixtures/` holds unified diffs generated from the real `git`
binary, committed so the parser suite runs on a machine with no git.

- **Assert against a named per-case fixture**, not against an offset into `working-tree.diff`. The
  case a test covers should be readable from the file it opens.
- **Do not hand-edit a fixture.** Change `Scripts/make-fixture-repo.sh` and re-run `make fixtures`;
  the fixtures are what git produced, and editing one turns the corpus into a record of what we
  expected rather than what git does.
- The `.z` files are NUL-separated. Read them as bytes and split on NUL — decoding them as lines
  will silently merge records.

Which cases exist, the two fixtures with surprising contents, and the repositories `make fixtures`
builds under `.fixtures/`: [golden-fixtures.md](references/golden-fixtures.md).

## Snapshot tests

`swift-snapshot-testing` is the **fourth** dependency, approved as **test-only** — attached to the
snapshot Xcode targets and never to `Package.swift`, so the two shipped apps stay on three.

- **They must be app-hosted**, which is why the target sets `TEST_HOST`. A SwiftPM test target is
  hostless and a SwiftUI view renders blank in one.
- **The suite must be `@MainActor`.** Rendering off the main actor traps, and the crash reports
  **"0 tests passed"** — the suite goes green having rendered nothing.
- **Assert what ships.** Wrap the view the way the composition root wraps it, or the baseline
  silently stops covering whatever the wrapper draws.
- **One parameterised test, not twenty functions**, so adding a state is one line.
- **Prove a new suite can fail before trusting it.** Change a string the baseline captures, confirm
  red, revert, confirm green. A snapshot test that cannot fail is a decoration, and it looks exactly
  like one that works.
- **The phone's baselines are recorded locally; the Mac's are recorded on the CI runner**, and
  `make snapshots-mac` is expected to be red on your machine. Never record the phone's on CI, and
  never re-record the Mac's locally to make it green.
- **A re-record is a design change, and needs the design to have changed first.** If baselines move
  and `.claude/docs/design.md` did not, the screen has drifted from the document; fix the screen, not
  the baseline. See the `design` skill. Review every changed PNG by eye before committing.
- **Every `@Suite` here carries `.serialized`**, all twenty of them. The suites share one real window,
  so anything a render leaves behind is the next render's input, and waiting for it to clear means
  spinning the run loop — which lets another suite take the window mid-assertion unless nothing else
  can run. That cost 22 baselines in a single run.
- **A view that takes focus raises a software keyboard, and a keyboard is geometry.** It never appears
  in a raster and it still shortens the screen the layout is measured against. The rise is
  asynchronous and lands on **whichever render is laying out when it arrives**, not the next one, so
  the harness drains on both sides of every render.
- **A clean run prints nothing from the probe.** A `[snapshot] … safeBottom=` line means a render was
  laid out against an inset past 40pt, which no real safe area reaches — that baseline cannot be
  trusted whether it passed or not.
- **A green local run is not evidence of absence** when which render catches a fault is luck. This one
  was green here and red on CI three times running, because locally the keyboard landed on an
  iPad-dark render that structurally cannot show the damage.

Why each of these bites — the hostless-render mechanism, the trap that restarts the test host,
tolerance values and the drift measurements behind them, the recording commands for each platform,
how to read a failure, and the four wrong fixes behind the keyboard rules:
[snapshots.md](references/snapshots.md).

## Cover it as you write it, and run the gate before the pull request

**`make coverage` gives the same verdict CI gives.** It fetches `main`'s numbers, runs the same
measurement script through the same predicates, and exits non-zero on the same rows. Run it before
opening a pull request that adds code. Discovering a fallen row from a red pull request costs a full
CI round trip to learn a number that was computable locally the whole time — that happened five
times before the target existed, and the target exists because of it.

It takes several minutes: three passes, one booting a simulator and one rendering the Mac's panes.
That is the price of the answer and a fraction of what it replaces.

**The gate counts regions, and a region is smaller than you think** — an `if`, a `guard`, a `case`, a
ternary, **or a closure body**. So write the test as you write the code, for each of these:

- **Every `guard … else` and `if let … else` failure branch.** The happy path arrives free with the
  first test; the refusal does not. A new file typically ships two or three of these and they are the
  usual cause of a fallen Unit row.
- **Every `??` fallback.** It is a region of its own and it is invisible until something takes it.
- **Every new `case`** added to an enum a `switch` covers — including the ones folded in with
  others, which the compiler will point at but the coverage export will not.
- **Every computed property and static factory, asserted directly.** Being *used* inside another
  test does not cover a property that test never reads. `sentence` and `thisProcess` both slipped
  through exactly that way.
- **Every fallback a view draws.** A `?? "Another process"` inside a `Ui` body needs a **snapshot
  subject of its own** — the states you photograph are the states you cover, and a state you argued
  for in a comment but never rendered is a state nothing holds you to.

**An action closure in a view is no longer counted, and that has a rule attached.** A snapshot
renders a view and never presses its controls, so a closure like
`onRestart: { Task { await model.restart() } }` was uncovered by construction and every control added
to a screen lowered the Snapshot regions row. Since 2026-09-04 the regions column leaves those out:
a closure returning `()` draws nothing, so it is outside what that row asks. Its **lines are still
counted**, because a closure written inline shares them with the view it sits in.

So the rule that replaces "read the export and say so to Davide":

- **Keep an action closure to one call into the model.** Its body is now judged by nothing — the
  views scope is the only row that sees view code, and this takes it out of that row.
- **A closure that grows a branch has outgrown a view.** Move it to the model, where the Unit row
  judges it. Do not argue it back into the denominator, and do not leave a `guard` or a `??` inside a
  `Button`'s action where nothing will ever hold you to it.
- The exclusion is closures, not methods: a named method in a `Ui` file **is** still counted, because
  it has a name and a test can call it.

## Test kinds, and the coverage gate

A test declares its kind by **which directory it lives in**, because a directory is already a
bundle here and a bundle is the finest thing a coverage profile can be scoped to. Three kinds:

| Kind | Where | What it is |
|---|---|---|
| Unit | `Packages/Granita/<Unit>/<Feature>/<Layer>Tests/` | In-process, on the host, no simulator. The default — everything that is not one of the two below |
| Ui | `Apps/GranitaMobileUiTests/` | Behavioural: a screen rendered and driven, asserting what changed. **None exist yet** |
| Snapshot | `Apps/GranitaMobileSnapshotTests/` and `Apps/GranitaMacSnapshotTests/` | Rendered against a committed baseline — the phone on a simulator, the Mac on the machine itself |

The `Coverage` job runs the suite once per kind, plus once with the profiles merged, and reports a
row per kind and nothing else. **Every value is gated**, line and region, for every kind that both
this run and the last `main` run put a number on. Plain ratchet, no floor, no slack. A kind measured
for the first time is not judged — it joins on the next `main` run.

- **A row of dashes is not a zero.** `Ui` reads `—` because the target does not exist yet.
- **Read the Snapshot row as "was this rendered", not "was this asserted".** Line coverage cannot
  tell a rendered line from a driven one.
- **Do not "fix" a number by moving snapshot tests into the package.** The split is the reason the
  numbers mean anything.
- **When a row falls, read the per-file export before touching the scope.** The tell is whether the
  code the row cannot reach is code that *should not be there*: fix that first, then ask whether the
  predicate is still wrong.
- **The bar for `UNREACHABLE_FILES` is "unrunnable by construction", never "hard to test".** Adding
  a name there is a redefinition, so it comes with a rename of the scope string. The Snapshot row's
  action-closure exclusion meets the same bar at a finer grain, and paid the same price.
- **The rows have different denominators, so do not subtract them.** Only `All tests` spans the
  project. Coverage rising after tests are deleted is the signature of this, not of an improvement.
- **Changing what a row measures un-judges it for one run.** Redefine deliberately, and expect one
  run with that row unenforced.

What each row is measured over and why, the 2026-08-23 measurement behind the Snapshot row's scope,
the denominator hazard in full, and the recorded redefinitions including the one that was
wrong: [coverage-report.md](references/coverage-report.md).
