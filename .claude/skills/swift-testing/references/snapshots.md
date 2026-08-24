# Operating the snapshot suites

Tolerances, the recording procedure and how to read a failure. Evidence behind the rules in the
`swift-testing` skill's "Snapshot tests" section.

```bash
make snapshots         # render and compare against the committed baselines
make record-snapshots  # re-record all of them after a deliberate design change
```

`swift-snapshot-testing` is attached to the `GranitaMobileSnapshotTests` Xcode target and to nothing
else.

## Why the suite must be app-hosted

A SwiftPM test target is hostless: there is no key window, so a SwiftUI view lays out against
nothing and renders blank. `drawHierarchyInKeyWindow: true` needs a real host, which is why the
target sets `TEST_HOST`.

## Why the suite must be `@MainActor`

Swift Testing runs `@Test` functions off the main actor, and rendering touches UIKit view
properties, which trap.

The trap is worse than a failure: the crash restarts the test host and the retry reports **"0 tests
passed"**, so the suite goes green having rendered nothing.

## Why the view must be wrapped the way it ships

`.navigationTitle` renders nothing outside a navigation container, so an unwrapped baseline silently
stops covering the title bar.

## Why one parameterised test

`@Test(arguments: Case.all, SnapshotLayout.all)` produces every state × layout from one function, so
adding a state is one line.

## Calibrating the tolerances — and proving they bite

`perceptualPrecision` is the **per-pixel colour** threshold and stays loose (**0.87**) to absorb
runner drift. `precision` is the **area** budget and must be **tight (0.999)**.

**Aura's 0.98 was inherited and is wrong here.** It allows 2% of pixels to move, and on a
mostly-empty screen a whole changed sentence is ~1.6% — the suite stayed green after "Local network
access is off" became "…is disabled". Aura's screens are dense; a budget calibrated for them hides
real changes on sparse ones.

**Prove a new suite can fail before trusting it.** Change a string the baseline captures, confirm
red, revert, confirm green. A snapshot test that cannot fail is a decoration, and it looks exactly
like one that works.

## Recording: the phone locally, the Mac on CI

**The phone's baselines are recorded locally.** `make record-snapshots` deletes the baselines and
runs the suite **twice**: the first pass writes each missing baseline and fails that same run, so
only the second pass tells you what was written renders stably. **Never record the phone's on CI** —
that turns the test into a recorder of whatever the code does.

**For the Mac that rule is inverted, and `make snapshots-mac` is expected to be red on your
machine.** A headless runner's window renders at 1× and a Retina laptop's at 2×, and the same code
draws measurably different pictures: **the drift is 0.737% of pixels against 0.162% for a real
one-word change**, and no tolerance separates them.

The procedure: push, let `Snapshot tests (macOS)` fail, then

```bash
gh run download <id> -n snapshot-diffs-mac -D <dir>
Scripts/adopt-mac-baselines.py <dir>
```

**Do not re-record the Mac's locally to make it green** — that is what turns every pull request red.
`make record-snapshots` cannot reach them for that reason. See `decisions.md`.

## Before committing a re-record

- **A re-record is a design change, and needs the design to have changed first.** If baselines move
  and `.claude/docs/design.md` did not, the screen has drifted from the document; fix the screen, not
  the baseline. See the `design` skill.
- **Review every changed PNG by eye.** Re-recording is the one operation in this repository that can
  make a wrong screen permanently correct.

## Reading a failure

- Baselines live in `__Snapshots__/<source file name>/`. The directory is named after the **source
  file**, not the test type, so renaming a test file orphans its baselines.
- Mismatches are written to `__SnapshotFailures__/` (gitignored) and CI turns them into one
  self-contained HTML page, uploaded as `snapshot-diffs`. Read the diff; do not guess.
- Reference PNGs are **16-bit Display P3**. `sips` and other 8-bit tooling truncate them silently and
  will report two different images as identical.
