# The side-by-side unit is the paired run, and its cells ride the hunk's scroll

Issue [#57](https://github.com/fardavide/granita/issues/57). The design returned 22 September 2026
and every call is in [`design-side-by-side.md`](../design-side-by-side.md); three of them are expensive
to reverse and belong here.

**A paired run opens into two columns and nothing else does.** Not the file — four rows in five of an
ordinary change set are context, and context is the same string drawn twice, so the whole-file form
halves the width of every row in order to align the rows that are identical and then asks the reader
to check that they are. At 390pt it takes an ordinary line from 49 characters to 22. Splitting the
run instead spends those 22 characters only where two sides exist, and leaves the other four rows in
five at the width they have now. This is the call most likely to be overruled, because everyone has
seen GitHub's two columns and this is not them.

**The cells ride the hunk's scroll offset rather than sharing a scroll with it, and the return could
not be built as written.** Design §4.1 asks for "one drag moves the context and both cells together"
and reaches for the shared hunk scroll to get it. Content inside a `ScrollView` travels as one piece,
so two cells at fixed screen positions cannot both stay put while it slides — the sentence is
geometrically impossible in the form it was drawn. What ships reads the offset the hunk's scroll
already reports and applies it to each cell, which produces the same behaviour from the other end:
one scroll, one gesture, and nothing that can desynchronise. Davide chose it over a per-block scroll
on 22 September 2026. **It has not been pressed in the running app**, and the one thing it cannot do
is give a block travel of its own: a cell moves by the context's distance, so a long line in a narrow
cell can reach its end after the context has reached theirs.

**The toggle stays live on a change set it can do nothing to.** An all-additions change set has no
paired run, so pressing the toolbar item draws identically — which is the letter of the rule against
shipping a control that does nothing. It is kept anyway, on Davide's call of 22 September 2026:
*"while there is no change, it will not do anything, but it will save the setting for the future."*
The perceivable effect of a setting is that it is remembered, and the alternative — a control that
materialises once the fifth file arrives carrying a run — is a control appearing mid-scroll, which is
worse. This is a statement about what kind of control it is rather than an exception to the rule.

**Two smaller departures, recorded so they are not re-derived.** The anchor across a mode change is
the *file* rather than the line: `scrollPosition(id:)` positions by section identity and a section is
a file, so line-level restoration is not built and the toggle inherits the 120pt short landing
already in [`status.md`](../status.md). And git's no-newline annotation **ends** a run here, where
`WordDiff` looks past it — the annotation is not a line of the file, so it has no side to be drawn
on, and lifting it out of a block would put it somewhere the parser did not.

**What the return raised and this slice did not take.** `SPEC.md` §10's sticky-height cache does not
exist — what holds the no-reflow line is `reservedRows` plus append-only loading — and nothing here
needed it, because a run of `d` deletions against `a` additions is `d + a` rows unified and
`max(d, a)` split, which is arithmetic over the model rather than a measurement. §10's claim that the
code size is its own setting was also never true: it is two constants in `DiffPaneLayout`. The
return's calls 10 and 11 build that setting and are deliberately out of scope here, on Davide's call.

