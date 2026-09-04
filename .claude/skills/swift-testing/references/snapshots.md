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

## The window is shared, so one case's keyboard is the next case's geometry

`drawHierarchyInKeyWindow: true` renders through the host app's **one real window**, and in that mode
swift-snapshot-testing ignores the layout config's declared safe area entirely — it resizes the live
window and uses whatever safe area the window reports. A keyboard raised by whatever rendered *before*
is therefore still in the layout, and it never appears in the raster, because it lives in its own
window. **It appears as geometry.**

It cost a baseline on 2026-09-04. `a-comment-adrift-iPhone-light` failed on CI, byte-identically on two
runs and green on this machine every time. The case before it in the same `.serialized` suite opens
`ReviewSheetView`, which focuses its note field `.onAppear` and carries a `placement: .keyboard`
toolbar. The next render got a **387.00pt bottom inset**, and one short frame produced two symptoms
that read as unrelated defects:

- the review capsule is an `.overlay` on `ContinuousDiffView`'s frame, so it drew 387pt up its screen;
- the page colour is one `.background(Color.diffPage)` on that same frame, so it stopped before the
  10pt gap between two files — which is `Color.clear` and has no colour of its own — and the gap showed
  the window's white;
- **and no row moved**, because a scroll view absorbs a bottom safe area as a *content* inset rather
  than by clipping. That is what made it look like two bugs instead of one.

The harness now applies `.ignoresSafeArea(.keyboard, edges: .bottom)` to every subject. No baseline in
this suite contains a keyboard or intends to avoid one, so the keyboard's contribution here can only
ever be state one test left behind. Dismissing the responder instead would trade a deterministic
modifier for a wait on an animation, and this harness has no waits by design.

Two things this teaches beyond the fix:

- **A dark baseline cannot catch a missing page.** `systemBackground` and `systemGroupedBackground` are
  *both* black in dark mode, so the same defect is invisible there. Only the light renders witness it.
- **Reproducing locally is not evidence of absence** when the mechanism is a leak between cases: the
  interleaving is deterministic per machine and differs between this Mac and the runner.

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

## Never run two `make snapshots-ios` at once, and what it looks like when you do

Two `xcodebuild test` invocations against one derived-data path race each other. Observed on
25 August 2026: the second run reported `** TEST FAILED **` naming a single parameterisation of
`ServerDiscoveryViewSnapshotTests`, **wrote no failure artifact at all**, and the same suite passed
on a quiet re-run of the same commit and the same baselines.

**The tell is the missing artifact.** A real mismatch always leaves a PNG under
`__SnapshotFailures__/`; a run that names a failing test and writes nothing did not get as far as
comparing anything. Read the directory before reading the test name.

The suspect for *why that particular test* is `ServerDiscoveryView`'s searching state, which is the
only subject in the phone's suite carrying a running animation — `.symbolEffect(.variableColor
.iterative)` — so which frame the rasteriser catches is a function of when it is caught. **That is a
suspicion and not a measurement**: it was not reproduced under load deliberately, and the only thing
established is that a quiet machine renders it identically every time. If this recurs on an
uncontended run, that symbol is where to look first, and pinning the effect off for the baseline is
the fix that does not weaken the assertion.
