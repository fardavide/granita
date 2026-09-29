# The review panel shipped as a settings screen, and §7 had drawn a panel

Davide's first look at it: *"the comment panel looks awful and doesn't respect design"*. He was right,
and the gap was not a detail — it was the whole surface.

**What went wrong is a specific failure worth naming: the frames were read for their *content* and not
for their *treatment*.** Every string was in the right place, every state was covered, and the
structure came out of `List { Section { … } }` — which is what iOS gives a preferences pane. Stock
`.insetGrouped` section headers, a full-width card per control, a plain two-line row per comment, and
*Copy review* as one more line of text among them. The design's own markup was sitting in the
document the whole time with the numbers in it.

What §7.6 actually draws, and what is built now:

- **A 52pt header of its own**, not a navigation bar: `Close` at the leading edge, `Review` centred,
  and the count at the trailing edge **in monospace** — which is what keeps the title centred while
  the number grows. The first build put the count in a `navigationSubtitle`, which stacks it under
  the title and moves it.
- **Monospaced, uppercase, letter-spaced section labels** — the app's own caption idiom, the one the
  design document itself is set in — rather than the system's section headers.
- **Cards at radius 10 on the grouped page**, which is the same page-and-card pair the diff already
  uses for its files, so the review reads as belonging to the screen it came from.
- **Every comment row carries the 3pt indigo rail**, at the same width and corner the gutter draws.
  That is the single most important thing that was missing: it is what makes a row in this list and a
  mark in that scroll *the same object* rather than two reports of one. The anchor label is in the
  rail's own indigo with the separating colon left secondary.
- **A stale row is tinted amber across its whole width**, with an amber rail and a warning glyph
  before its label — the one row here that is a warning.
- **Show text is a centred link with a chevron**, not a disclosure row in a card of its own.
- **Copy review is a filled indigo button, 50pt, pinned to the bottom** where the thumb is, and it
  turns green with a checkmark for the two seconds it says *Copied*. It was a list row.

**And the amber the design picked is the app's own.** `#C0821F` in the frames is
`Color.fileStatusAmber` to the byte — the colour `.modified` has carried since 0.6.0. `.orange` was
wrong twice over: it is what *conflicted* means, and it is not what was drawn.

