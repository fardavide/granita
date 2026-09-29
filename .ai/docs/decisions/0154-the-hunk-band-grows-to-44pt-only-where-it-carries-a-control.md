# The hunk band grows to 44pt only where it carries a control

Design §4 puts the expand control on the band's trailing edge in a 44pt hit area, and not the leading
edge, which is the gutter's column — a glyph there reads as a line number. Taken literally that makes
the band nearly four times its previous height, which is real screen on a phone; taken loosely it
makes a tap target a thumb misses, and a control that misses is a control that did nothing.

It is taken literally, and bounded: a hunk with no gap above or below it draws no control and keeps
the thin band it always had, so the cost is paid only where there is something to press. Whether four
of these in one file is too much is a question for the same thumb that owes §4 its other answers.

> Rejected: a hit area larger than the row it is drawn in. It overlaps the code above and below, and
> a tap that lands on a diff line and expands a hunk is worse than one that misses.

