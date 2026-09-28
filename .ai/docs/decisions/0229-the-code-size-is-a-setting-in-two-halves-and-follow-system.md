# The code size is a setting in two halves, and Follow system bends to the split's floor

Issue [#106](https://github.com/fardavide/granita/issues/106), 0.19.0. `SPEC.md` §10 had claimed
since the beginning that the code size is its own setting; it was two constants in `DiffPaneLayout`
until now. The calls are in [`design-code-size.md`](../design-code-size.md); three of them are expensive
to reverse and are here.

**Follow system now scales the code with Dynamic Type, reversing a standing rule.** `DiffLineHeight`
has said since it existed that the code does *not* scale, which left a reader who had enlarged every
other word on the phone reading eleven-point code. One point per step from Large, clamped to 8–17,
with Large landing on exactly today's 11 and 12 — so nobody's screen moves on the update. It also
makes §10's *"independent of Dynamic Type"* true only of the *Custom* half, and that sentence should
be rewritten rather than deleted.

**The split's *Follow system* is clamped at the largest size two columns still fit in, and the floor
does not bend.** Davide's call, 23 September 2026, on a conflict the issue was filed blocked on:
12pt is exactly twenty characters a side at 390pt, so every Dynamic Type size above Large would
otherwise leave a *Follow system* reader with no columns — an accessibility setting silently removing
a feature. Bending the floor was rejected because design §4.2's call 7 put it in characters precisely
so it is one rule at every width; honouring the size and disabling the layout was rejected because a
phone has no widening gesture to bring it back. **The ceiling is this width's rather than a constant
twelve**, so an iPad and a wide Mac window clamp nothing. What it costs is that a reader at a large
text size sees smaller code inside a block than around it. A *Custom* size is never held back —
capping the stepper was rejected as a ceiling that moves while a window is dragged.

**The split's size governs the whole scroll, not the block rows.** Two settings could have meant two
sizes on screen at once; they do not, because context drawn at one size beside a block drawn at
another is two text sizes in one file. So *Side by Side* chooses between the reader's two numbers,
and flipping it re-lexes every visible file exactly as a theme change already does.

### The disabled toolbar item was designed in #57 and never built

Design §4.2 and [`design-side-by-side.md`](../design-side-by-side.md) both say the toolbar item goes
disabled below the floor "carrying its reason". **It did not.** `SplitBlockLayout.fits` was consulted
only inside `DiffFileLines`, which closed the blocks and said nothing; the `Toggle` was never
disabled and no such sentence existed in the codebase. The state was reachable only by dragging a Mac
window, which is why eight releases of green checks never saw it — and this slice made it reachable
on a phone, which is what forced it.

It is built now, with the cause naming the lever: *Widen the window to review side by side* where the
room ran out, *Choose a smaller code size to review side by side* where the size did. The width is
asked first, because a row too narrow at 8pt cannot be fixed by choosing a size.

**Where that sentence is visible is a departure from the design's own wording.** A disabled toolbar
item can carry a tooltip on a Mac and a VoiceOver hint anywhere; a sighted phone reader sees a dimmed
glyph and nothing else, which is the "different unanswerable question" the dead-control rule names.
So the same sentence is also in the *Code size* screen's split group — the only place the reader can
act on it. **The diff screen alone still does not say it in words a sighted phone reader can read**,
and closing that would mean either a fourth piece of bottom chrome or an operable control that
explains itself when pressed. Neither was in this slice's scope; it is a question for a device
afternoon and for Davide.

### The appearance root is a composition root, and the coverage gate is what proved it

`AppearanceRoot` had been filed under `ClientSettingsPresentation` since 0.16.0. This slice gave it a
second job — measuring the window, so the *Code size* screen can say what a point size buys in
characters — and the Unit row fell by 0.2 points, entirely on that one file. A SwiftUI body cannot be
executed by a host test, so every line it gained was a line nothing could ever cover.

**The first answer was wrong and a baseline disproved it.** The Unit scope excludes view bodies and
implements that as *in `Ui`, or named `…Screen`*, so the obvious reading was that the predicate was
one suffix short and `AppearanceRoot` belonged with the screens. Moving it there puts it in the
Snapshot scope, so it was given the baseline [`design-appearance.md`](../design-appearance.md) had asked
for in 0.16.0 and never got — and **the picture came back light with the picker set to Dark.** The
snapshot harness injects the interface style as a `UITraitCollection`, so `preferredColorScheme` sets
the `colorScheme` environment for descendants and never reaches the window that paints the chrome. A
render of this view is a picture of the harness, not of the app.

**Which is the definition of the other category.** `COMPOSITION_ROOT_LAYER`'s own note describes the
case it was written for: *"a module called `Presentation` that a rendered baseline cannot draw and a
host test cannot construct is a module both scopes have to carry a clause about."* That is this file
exactly, and it is what it does: it observes the one app-wide settings model, applies one modifier,
and hands four values to the scene to put under four environment keys. So it moved to
`Client/App/Main`, where both rows are exempt by design and where the architecture doc already says
this kind of code lives.

**No coverage predicate changed**, which is the point: the file was misfiled and the gate found it.

**A root holds wiring and nothing else, and this one does.** The row-width arithmetic is
`DiffPaneLayout`'s and unit-tested; the text-size mapping sits beside `AppearanceModel` and is
unit-tested; `note` is the model's. What is left in the root is a geometry read, a size-class read
and one call.

### Two widths, and only one of them decides anything

The *Code size* screen states what a size buys in characters, which needs the width the diff is read
at — and it is a sheet, so it cannot see the pane it is describing. The root is the only view whose
bounds *are* the window, so it measures there and `DiffPaneLayout` takes the tree's width off
wherever a tree could stand, open or shut. `WorktreeDiffScreen` keeps measuring its own pane.

**The measured width governs every decision and the derived one only states a number.** They agree
exactly on the phone and to within a divider beside a selector column, so a disagreement costs a
character in a sentence and never a press — which is what made two measurements acceptable rather
than a second source of truth.

**`ReaderTextSize` crosses a feature boundary because its mapping can exist only once.** The diff
needs the reader's text size to draw the code and the settings sheet needs it to say what a size
buys; the two features are siblings over `Domain` and neither may import the other's `Ui`. The switch
onto `DynamicTypeSize` lives beside `AppearanceModel` — in `Presentation` rather than in `Ui`, so a
test calls it — and the composition root hands the answer to `ClientViewerUi`'s environment. One
mapping, no new edge in the graph.

