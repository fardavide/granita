# A refused batch of diffs stops being silent, and a file gains a case to fail into

*(13 September 2026, 0.12.0)*

`ClientViewerModel.fetch` read `guard let diffs = try? await repository.diffs(…) else { return }`.
A refused batch was therefore dropped entirely: every file in it stayed `awaiting`, which on screen
is an opaque card of nothing under a header carrying a real name and a real `+68`. `inFlight`
emptied in the `defer`, so a later scroll *could* re-ask — but **a reader already sitting on the file
scrolls nothing, so nothing did**, and the blank was permanent for the life of the screen.

`ContinuousDiffContent` had nowhere to put it: the enum was `awaiting | ready` and the model was
holding an `ApiFailure` with no home. It has a third case now, `failed(FileChange)`, and
`reservedRows` answers for it **identically to `awaiting`** — a failure that answered differently
there would change the height on the way in, which is `SPEC.md` §10's reflow arriving from the one
direction nobody can press.

**The failure is kept once for the batch and not once per file**, because it is a fact about the
request and the request carried five of them. `DiffBatchFailure` is derived from the entries rather
than stored, so the bar cannot count cards that are no longer blank.

### A failed file needs a set of its own, and *Try Again* is what empties it

Found by reading `ContinuousDiffLoading.next`, which filters on `held`, `inFlight` and `deferred`. A
failed file that merely left `inFlight` is eligible again on the very next position update — and a
scroll reports a position per file appearing, so a reader nudging a dead Mac would re-ask it every
frame and each row would flicker between *couldn’t read this file* and *reading from your Mac*. The
function takes a fourth set, `refused`, and `retryDiffs` is the only thing that empties it.

### A cancelled batch marks nothing

`.cancelled` is the app tearing down its own `.task` when the view goes away. A card reading
*couldn’t read this file* because the reader pressed Back is the app blaming the Mac for what the app
did, so that case returns without touching an entry — the same rule `load()` already followed for the
change set itself.

### The recovery is one control, and the failure class chooses which

Design §9's call, and it is a safety property rather than a preference. A revoked pairing refuses
every later request too, so a *Try Again* there is a control that cannot work — **this project's
worst defect** — and a per-file retry would have drawn that dead control once per blank card. One bar
means the class picks the control: *Try Again*, *Back to Worktrees* or *Pair Again*. It also sidesteps
the 44pt floor, which a per-file control could not: the box it would live in can be 18pt tall, so the
control would exist on large files and not on small ones.

`WorktreeDiffScreen` therefore takes `onPairAgain`, the same closure the worktree list is given, and
*Back to Worktrees* is the environment's own `dismiss` — this screen is pushed on a stack in both
layouts, the phone's spine and the iPad detail column's own stack, so the pop is real in both.

Rejected: reusing the collapsed bar's `1,558 lines · Load diff` row. That bar lives in the header's
slot and shuts the body, so moving a failed file into it changes that file's height — reflow, above
the viewport, on a failure that arrives asynchronously. It is also the wrong gesture: *Load diff* is
an offer the reader may decline forever, and nothing about a refusal was decided.

### Sixteen failures, four sentences, and one that never reaches the bar

`ApiFailure` has sixteen cases; the design names four. The rest fold into the nearest by the only
axis the bar has — what the reader can do about it — so a rate limit, a stale content hash and a
request this phone could not build are all *your Mac would not answer that* and all worth pressing
again. `requestNotBuildable` folds the other way, into *out of reach*, because a host that will not
make a URL is the Mac being unreachable as far as anyone holding the phone is concerned.

### The estimate is drawn and no number is

One 7pt bar per reserved row is the estimate made visible, and §10 says the estimate is allowed to be
wrong. It survives because there is nothing to contradict: the widths are ragged, the figure column
is empty, and a file that arrives with fewer rows replaces a shorter block. **A reader cannot count
what they were shown**, which is the whole of why drawing it is legal. The widths are folded from the
file's own identifier with FNV-1a and a xorshift rather than through `Hashable` — Swift seeds
`hashValue` per process, so a picture built from one is a different picture every launch: invisible
in the app and fatal to a baseline.

### The sweep is photographed still, and that is the design's own instruction

An infinite repeating animation has no frame a raster can be pinned to, so every baseline holding an
unarrived file renders with Reduced Motion — where design §9 puts the sweep's absence rather than a
slowed version of it. What the light does under a thumb is checked by looking at the app, which is
where this project has always checked motion. The bars, the sentence, the marker and the bar's three
states are all photographed.

### The second word is a flag, not a clock

Design §9 reverses §8's own elapsed stopwatch here: one wait and one spinner earned a clock, and five
files in flight would earn five of them ticking in a scroll. It is one `Bool`, flipped by a task that
sleeps for the threshold and is cancelled by the batch's `defer` — which also means an ordinary read
never writes it. A `TimelineView` was rejected outright: a per-second rebuild of anything inside this
scroll is a per-second rebuild of the scroll.

### The sticky row is a rendering position

`visualEffect` rather than an offset applied in layout, which is the same distinction that makes
pinned section headers legal in a scroll that may never reflow: it runs after layout has decided
everything, so the row travels and no height moves with it. It is `nonisolated`, because that closure
runs outside the view's actor and a `GeometryProxy` is not `Sendable`. `DiffFileHeader.height` became
`nonisolated` with it, rather than being restated — a header height written in two places is the
drift that made a shut file's bar and its header draw two different columns in 0.6.0.

### A full-width bar hard against the bottom safe area is drawn twice

*(13 September 2026, 0.12.0)*

Found by a baseline, and it took three wrong fixes to isolate. `DiffFailureBar` shipped its first
build flush with the bottom of the screen, and every phone baseline came back with its **trailing
control drawn a second time at the top of the window**, above the navigation bar — the `Try Again`
button in one state and the stock activity indicator in another, always matching the subject and
never the two lines of text beside it.

The material was not it: `bar` and `regularMaterial` behave identically. The `.transition` was not it
either, though it was inert and came out on its merits. What settled it was rendering the bar in a
**component** suite, with no `NavigationStack`, no toolbar and no overlay: the duplicate was still
there, so it belonged to the bar rather than to its composition. Moving the bar up then moved the
copy up by the same amount, which is the tell — iOS 26 reads a full-width container sitting on the
bottom safe area as bottom-bar chrome and mirrors its trailing control.

**The fix is a measurement the design already gives**: 34pt of clearance for the home indicator. The
bar floats, like `CommentInstructionBar` above it, and the control is drawn once.

**`CommentInstructionBar` never had this** and that is why it was the useful comparison: §7.1 floats
it 12pt from the sides and 38 from the bottom, so it has never been flush with anything. A component
that is chrome at an edge is worth rendering **on its own** before it is rendered in a screen — the
screen's baseline showed the same fault and made it look like a composition problem.

