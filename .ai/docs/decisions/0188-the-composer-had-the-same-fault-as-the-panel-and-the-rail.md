# The composer had the same fault as the panel, and the rail is the thread through all three

Once the review panel was rebuilt against the frames rather than against their prose, the composer was
obviously the next thing wrong with it: the anchor was a grey monospaced label, the excerpt three
loose grey lines, and nothing tied either to the rows behind the sheet.

§7.2 draws:

- **A 44pt anchor row carrying the rail**, with the path in the primary colour and only its colon
  demoted. This is the third surface the rail appears on — the gutter, the instruction bar, and here —
  and that repetition is the whole reason a reader knows the sheet in front of them belongs to the
  rows behind it.
- **The excerpt on a card tinted in the rail's own colour at 12%**, radius 8, rather than three lines
  of text on the sheet's background.
- **The gutter's own figures beside the code**, right-aligned in a 34pt column. This is the half that
  matters: the excerpt exists so a reader who landed one row off finds out *before* they type, and
  what they would recognise is the number they were aiming at. The text alone reads equally plausibly
  one row up, which makes the excerpt a sample rather than a receipt.

That last one is a Domain change rather than a styling one — `CommentSelection.excerpt(of:)` returns
`ExcerptLine`s carrying `DiffGutter.number(of:)` beside the quoted text, so the composer and the
exported document still come from one place and still spell a no-newline marker the same way.

**The chevron §7.2 draws at the trailing edge of that row is not built**, and deliberately: it is the
range `Menu`'s affordance, the three operations behind it do not exist yet, and a chevron that opens
nothing is the dead control this project refuses. It lands with them.

