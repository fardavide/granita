# The Mac's snapshot baselines are recorded on the CI runner, and the phone's are not

The `swift-testing` skill says it in as many words: **record locally, never on CI**, because a
recorder on CI turns the suite into a record of whatever the code currently does. That rule stands
for the phone. For the Mac it is inverted, and the reason is two numbers rather than a preference.

With the raster pinned and both sides rendering 1240 × 1120, the same code still produced different
pictures on this Mac and on a runner:

| | share of pixels differing by more than 64 levels |
|---|---|
| Cross-machine drift, identical code | **0.737%** |
| A real one-word copy change, same machine | **0.162%** |

**The noise is four and a half times the signal.** There is no `precision` between them: any budget
loose enough to absorb the drift is four times looser than a changed word, so the suite would go
green on exactly the class of change it exists to catch. The skill's own calibration story — 0.98
was rejected because it hid a changed sentence — is this same argument, and it points the same way
here.

### What is actually known about the cause, and what is not

Worth separating, because the first account written here asserted a mechanism that the measurements
only partly support, and a confident wrong story is what stops the next person looking.

**Established.** The runner's window renders at 1× and this laptop's at 2×: before the raster was
pinned, identical code produced 620 × 560 there and 1240 × 1120 here, and
`bitmapImageRepForCachingDisplay` takes its resolution from the window's backing scale. A hosted
macOS runner is headless. `NSWindow.backingScaleFactor` is derived from the screen and has no setter,
so pinning the raster — necessary, and done — cannot reach it.

**Also established, by measuring the images rather than reasoning about them:**

- Both sides are genuine 2× rasters afterwards. Among blocks sitting on a content edge, the share
  that are a single flat colour is 1.1% on the runner and 34.9% here; a doubled 1× image would be
  ~100%. The runner is not upscaling.
- The residual is not a whole-image shift. Rolling this laptop's image one device pixel up improves
  the mean absolute difference from 1.42 to 1.08 — so there is roughly half a point of vertical
  offset — and leaves most of the difference in place.
- It concentrates in the two smallest text lines. The worst rows are the footnote captions, at mean
  absolute differences of 32–40 out of 255, while the rest of the pane is close.

**Not established.** That glyphs "snap to a different grid" was the first explanation offered here and
it is an inference, not a finding. It fits the offset and the concentration in small text, and the
edge-block figures above sit awkwardly with it: this machine produces the *coarser* image of the two,
which grid-snapping does not predict. The backing-scale difference is the only environmental
difference actually demonstrated, and it is plausibly upstream of the rest — but the mechanism is
open.

Settling it would need a Mac with a 1× display, or a virtual display attached to the runner. It was
not bought, because no decision turns on it: the drift is four and a half times a real change
whatever produces it.

So the runner is the only machine whose renders are reproducible on the machine that gates them, and
`Scripts/adopt-mac-baselines.py` takes them out of the job's own diff artefact. Davide chose this on
22 August 2026 over three alternatives: gating the Mac suite locally only, which leaves a check
nobody runs; dropping the image assertions, which gives up checking the design was built as drawn;
and giving the runner a virtual 2× display, which is fragile infrastructure on a hosted runner and
could not be verified without several more round trips.

**What it costs is that `make snapshots-mac` is red on a developer's Mac, permanently and by
design.** That is a loaded gun pointing at the next session, whose obvious move is to re-record
locally and "fix" it — which makes every pull request red instead. Three things are arranged against
that: `make record-snapshots` no longer touches the Mac's baselines at all, `make snapshots-mac`'s
help text and comment say the red run is expected, and the adoption script's docstring carries the
measurement. The target is still worth running locally for its diff report, which is what shows a
person what moved.

**The rule that does not change is that a picture nobody looked at is not a baseline.** Adopting a
runner's render is accepting an image sight-unseen unless someone opens it, so the script prints
every file it writes and says so.

