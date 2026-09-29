# A keyboard nobody could see moved a capsule 387pt, and four wrong fixes are the point of this entry

`a-comment-adrift-iPhone-light` failed on CI and passed here, byte-identically across three runs
there. Same Xcode 26.6, same iOS 26.5, and it passed locally on CI's own device, so none of the usual
suspects.

The render differed in three bands and nowhere else: the review capsule 387pt up its screen, one 10pt
inter-file gap white instead of `#F2F2F7`, and the capsule missing from where it belonged. **Those
are one fact.** `ContinuousDiffView`'s `ScrollView` both hosts the capsule overlay
(`WorktreeDiffScreen.swift:233-234`) and paints the page (`ContinuousDiffView.swift:190`), so a frame
387pt short at the bottom moves the overlay *and* stops the page rect before the gap — which is
`Color.clear` and has no colour of its own. **No row moved**, because a scroll view absorbs a bottom
safe area as a content inset rather than by clipping, and that is what made it read as two unrelated
defects.

### The mechanism, and why it took so long to name

`ReviewSheetView` focuses its note field `.onAppear`, which raises the software keyboard
**asynchronously**. `drawHierarchyInKeyWindow: true` renders through the host app's one real window,
and in that mode swift-snapshot-testing ignores the config's declared safe area and lays out against
the live window's — so the keyboard's inset is in the geometry. It never appears in the raster,
because a keyboard lives in its own window. **It appears as a shorter screen.**

The part that defeated four attempts: **it does not land on the next render.** It lands on whichever
render is laying out when it arrives, and that is a different one on every machine and every fix.
Both machines catch it exactly once per run; only the victim differs. Here it was
`a-suggestion-exists-iPad-dark`, where the capsule does not exist at regular width and the page
artefact is black on black — so it corrupted a render that structurally cannot show it, and every
local run was green. On CI it was a phone-light render, which can.

### Four fixes that were wrong, each refuted by measurement

Recorded because the sequence is the lesson, not the destination:

1. **`.ignoresSafeArea(.keyboard)` on the subject** — byte-identical failure. The subject is wrapped
   in a `NavigationStack`, so the modifier lands on the wrapper and never reaches the scroll view.
   Measured later: it moved the inset from 261 to 319 and onto a different render rather than
   removing it.
2. **Resign first responder and spin the run loop before the render** — 22 *unrelated* baselines went
   red. Spinning the main run loop while sixteen suites were unserialised invites another suite's case
   to take the shared window mid-assertion, which is the hazard rather than the cure.
3. **`endEditing` after each render** — the rise was already queued and arrived anyway.
4. **`drawHierarchyInKeyWindow: false`** — it *does* place the capsule correctly, which is what proved
   the fault was in the live window rather than the view code. Rejected on fidelity: it rasterises
   through `layer.render`, which does not draw `UIVisualEffectView`, so the "3 files" chip vanishes
   entirely and the navigation title renders pale grey on grey. Re-recording against that would leave
   a shipped control invisible to every future baseline.

Each fix removed one route and the keyboard drifted to the next render in line —
`a-comment-adrift-iPhone-light`, then `the-review-is-open-iPad-dark`, then
`the-review-is-open-iPad-light`. Whack-a-mole, because closing routes is not closing the window in
which a keyboard can be up.

### What actually fixed it

Three things, and none works alone:

- **Every suite is `.serialized`.** Sixteen were not, including all four that raise keyboards.
- **The keyboard is drained on *both* sides of every render**, dismissing on each turn and requiring
  three consecutive quiet turns. Once is not enough, and one quiet turn cannot tell a keyboard that
  has gone from one that has not arrived. Draining before the render is what catches a late rise, and
  it is only safe because of the serialization.
- **The iPad's review column no longer takes focus** (`ReviewSheetView.swift`). That one is a product
  call that stands without the test argument: the sheet is summoned and covers what the reader was
  reading, so §7.5's "type immediately" applies; the column opens *beside* a diff that stays live and
  readable, and stealing focus there throws a keyboard over half an iPad somebody is still reading.

The local signal went from "exactly one anomalous reading every run" to **zero**, which is the first
time any of this could be verified without a 30-minute round trip.

### What is left, named rather than fixed

`WorktreeRenameSheet` still focuses its field; `a-suggestion-exists-iPhone-dark` recorded
`height=511 safeBottom=271` while matching its baseline. It is pre-existing, has never cost a run, and
the drain plus the serialization now stands between it and the next render.

### The rules this leaves

In the `swift-testing` skill: a shared key window means a test's geometry can be set by any test near
it; **a green local run is not evidence of absence** when which render catches the fault is luck; and
**a probe that reports at `onAppear` measures the wrong moment** — that reading said `safeBottom=4`
for a render that was laid out at 261.

And in the `Makefile`: `IOS_SIM` hardcoded `iPhone 17` while `ci.yml` and `measure-coverage.sh` both
resolved `iPhone 17 Pro`. Three commands, two devices, and a `make snapshots` that could not give the
runner's verdict — which is the whole claim that target is made on. It is resolved now, by the same
expression the other two use.

