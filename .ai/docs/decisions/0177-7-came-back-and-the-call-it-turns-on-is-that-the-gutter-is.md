# §7 came back, and the call it turns on is that the gutter is a coordinate rather than a control

The design round trip for inline comments returned on 3 September 2026. Its headline is a single
structural decision that every other one follows from: **nothing opens in the diff.** No row grows, no
file re-lays out, no sheet pushes the scroll up. A comment is 3pt of colour at the leading edge and a
sheet at the bottom of the screen — which is what lets a feature that GitHub builds entirely out of
reflow live inside `SPEC.md` §10's no-reflow rule without touching it.

**The 44pt question was answered by re-classifying the target, and this is a departure with Davide's
sentence still owing.** A code row is 18pt at the smallest size a reader can choose. The design's
argument is that the 44pt minimum governs *discrete* controls — things with a boundary you must land
inside, where a miss produces nothing — and that one gesture recogniser over the whole gutter strip is
not one of those: it has no boundaries, no dead space, and no way to fail. A miss cannot produce
nothing; it can only land one row off. The remedies are paired with it rather than assumed: the
composer opens showing the code it is about to attach to, and its anchor is a full-size control.

`SPEC.md` treats a sub-44pt control as a defect with no exception, and the only exception ever
recorded here — 0.6.0's 26pt hunk band with a 44pt-wide control — was reverted in 0.6.1. **So this
ships as designed and is flagged rather than resolved.** The sentence being asked for is one line: *a
continuous spatial recogniser with no dead space and no internal boundary is not a discrete control.*
If Davide declines it, `GutterTarget` and the two gestures on `DiffFileLines` come out and the feature
needs a different way in — the design says the only one left is picking lines from a list, and argues
against it.

**Two more numbers came out of the arithmetic, and the code was right where the document was wrong.**
`design.md` §4 quotes the gutter as 39pt and the code origin as 48pt as though both were constants;
`DiffGutter.columnWidth` sizes the figures per file, so 39.4 is the four-figure case and the real
origin is 57.4pt there and 50.8 on a three-figure file. The design read the code rather than the
document and its measurements match to a tenth of a point. `§4` is corrected.

