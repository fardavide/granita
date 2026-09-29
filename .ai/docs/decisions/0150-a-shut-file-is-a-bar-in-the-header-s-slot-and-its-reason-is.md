# A shut file is a bar in the header's slot, and its reason is the field the specification forgot

`SPEC.md` §10 says a file marked viewed renders collapsed and that a file over 500 diff lines starts
collapsed with a *Load diff* affordance. 0.3.0 built the mark and left the diff open under it, which
made the toggle a control that moved a circle. This is the other half.

**The bar goes where the header goes**, in the section header's slot, with nothing under it. The
alternative — a header over an empty section — keeps two rows where the design draws one and leaves
the reason with nowhere to live. A shut file is therefore 44pt and not one row more, which is what
makes collapsing worth doing at all.

**Four reasons, and the reason is the whole point.** Design §4 added it to the specification and
argued it: without it the reader opens a file to learn there was nothing in it, which is the exact
cost collapsing was supposed to save. A binary file and a rename with no content change get **no
chevron at all** and the row stops being a button with it — there is nothing behind them, and a
disclosure control that discloses nothing is the smallest possible lie. The frame draws those two
chevrons faded; a faded chevron is still a chevron.

**"viewed", not "viewed 4 minutes ago".** The Mac stores a mark as the content hash it was set
against and keeps no time beside it, so the elapsed reading is a number this phone would have to
invent. Same shape as §3's truncation footer above, and the same answer: a sentence that is true
beats a sentence that matches a drawing. Putting a timestamp in the store is a change to `SPEC.md`
§5.5's viewed map on both ends for one adverb, and it is not one this slice asked for.

**An unread bar carries no empty circle**, which the frame draws on three of its four rows. The
circle in the file header is a *control* — it is the only writer of the mark there is — and the same
glyph on a row whose whole tap target opens the file would read as a second control inside the first,
which is §3's two-tap-targets problem in a 44pt row. So the mark appears on a bar only when it is
set, as a bare check, exactly as §3's selector row does it.

**A fifth case the design does not draw: the reader shuts a file by hand.** It has no reason line, so
the bar is one line rather than two. Telling someone they shut a file they have just shut is a line
that says nothing. It is photographed, because a state argued for in a comment and never rendered is
a state nothing holds anybody to.

**The reader's chevron is forgotten when the mark moves.** `viewed(_:)` clears the override rather
than preserving it, so marking a file read always shuts it — which is what §10 asks for and what the
frame says in one sentence. A mark that left an earlier *open* standing would be the one gesture in
this app that does half of what it says.

> Rejected: a `Bool` for the reader's answer defaulting to the automatic one. The difference between
> *the reader wants this open* and *nobody has said* is what lets a mark shut a file the reader had
> opened by hand, and one `Bool` cannot hold both.

