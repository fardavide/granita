# What an adversarial read of §7 found, and the four rules that came out of it

Five reviewers went over the slice against the frames and the layer rules, and every finding was put
to an independent skeptic told to refute it. Nine survived. Four of them are rules rather than
patches, and each is written into the code it governs.

**The gutter stops being a target while a sheet is up.** The composer's own detent enables background
interaction — that is design §7.2's whole point, so a reader can scroll the diff behind it and check
the caller they are about to complain about. It also leaves a live gutter under a sheet. Three
separate defects came out of that one fact: a tap behind the composer emptied the field the reader
had been typing into; a long press behind it fired a haptic for a hold that never happened; and the
toolbar, also live, could replace the composer without cancelling the run, leaving a square-capped
rail in the gutter, no composer, no instruction bar, and **every further gutter gesture a no-op for
the life of the screen**. One boolean threaded down to `DiffFileLines` answers all three. The scroll
still moves; only the aim goes.

**Document order asks the diff, because a line number cannot answer it.** `CommentedLines.first` is an
old-side number for a run that is entirely deletions and a new-side number otherwise, and the two
counters diverge the moment a file deletes more than it adds — so a comment on a deletion at old 105,
drawn near the top, sorted *after* an addition at new 50 drawn below it. Both the review list and the
exported document read backwards for that file. `ReviewedComment.ordered` resolves each anchor to its
row index instead, and the model re-orders as batches land, because at `load()` every file is still
awaiting and nothing can be placed.

**The Files button goes while the review has the column.** There is one sheet, so opening the selector
closes the review — which freed the slot, so the tree column slid back in *and* the same tree
presented itself as a drawer on top of it. Two file lists from one press. The same shape stranded the
review toggle when a reader deleted their last comment from inside the column: the chip was gated on
there being comments, and the column form has no Close of its own.

**A held row draws its own rail.** The screen passed only the composing run, so §7.1's square-capped
mark — which the section lists among the rules the held state obeys, and which is what makes a hold
survive scrolling away to find its other end — was drawn by nothing. The baseline for it was built by
hand from a `CommentRun` literal, so nothing caught it.

Three smaller ones went with them: `CommentRun`'s identity was its first row, so a hold beginning on
the first row of an existing comment collided with it in the `ForEach` and one of the two silently
did not draw; the composer's excerpt read `\.text` straight off the rows while the export went through
`CommentSelection.quoted`, so a no-newline marker appeared as a line of the reader's own code in the
one place they could see it; and the bar and the capsule carried `.transition`s with nothing animating
the state behind them, so both snapped.

**Two of the tests were the kind this repository keeps finding.** One asserted the pasteboard against
`sut.feedback(...)` — the same mapper on both sides, so deleting the heading or the `> ` prefix would
have changed them together and stayed green. The other asserted that the Files button *comes back*
while the review holds the column, which is the defect above written down as a requirement.

