# The files sit on a coloured page, because a gap the same colour as the rows is not a gap

*(1 September 2026, 0.6.1)*

0.6.0 built design §4's 10pt separation between files and it could not be seen. The gap was a clear
strip on a screen whose background is the same white as every row in it, so what shipped was ten
points of white between two white files — and Davide's first note on the release was "there's no
spacer between files".

The screen now draws what the review draws: a **grouped background** behind the whole scroll, an
**opaque card** behind each file's header, bar and lines, and the gap left clear so the page shows
through. It is one decision for every boundary — bar to bar, bar to header, header to code, and under
the last file — and it stays right when a file shuts, opens, or is still arriving, which is the
property a per-boundary rule does not have.

Expensive to reverse because it settles what every surface in the diff composites onto: the pinned
header and the collapsed bar are now opaque by contract rather than by inheritance, and the hunk
band's own fill is read against the card rather than against the window.

**The pair is the grouped one, and the first attempt was the plain one.** `systemBackground` over
`systemGroupedBackground` separates in light — white on grey — and in dark they are **both**
`#000000`, so the first rendering of this fixed one appearance and reproduced the original fault on
the other, which the dark baseline caught. `secondarySystemGroupedBackground` over
`systemGroupedBackground` holds in both: white on grey, then `#1C1C1E` on black.

Rejected: a `Divider` at each gap — it draws a line where the review draws a space, needs a rule for
which side of a boundary owns it, and says nothing at all under the last file. Rejected: colouring
the gap itself and leaving the rows transparent, which is the same pixels and puts the answer in ten
points of a lazy stack rather than in the screen.

