# The hunk band becomes a tear, and three of §4's own calls go with it

*(1 September 2026, 0.6.1)*

The design review came back a second time with the expander redrawn, and it replaces the band rather
than restyling it. **A bar says a control is here; a tear says something is missing here** — and the
second is the fact a reader needs while reading, because a broken edge registers before any label
does. The row is torn on the side the content is missing from, and that one rule produces the three
forms: torn above at the top of a file, torn below after the last change, torn both ways between two
hunks.

Three settled calls are reversed by it, and each was argued for here:

- **"Expansion lives on the trailing edge, not the leading edge: that is the gutter's column, and a
  glyph there reads as a line number."** The glyph moves into the gutter. The objection was right
  about a *chevron* and is the reason the new mark is not one: an arrow over three short rules **is**
  line numbers, near enough — they stand for the rows not being drawn, which is what the column is
  empty for.
- **"The band is 26pt and its control buys its hit area horizontally, 44pt wide rather than 44
  tall."** The row is 44pt tall, because in two of its three forms the row *is* the control and there
  is nothing else in it to press. The screen does not pay for it: the band was drawn above every
  hunk, and a tear is drawn only across a gap — most files now have fewer of these rows than they had
  bands, and a file the diff drew whole has none at all.
- **"A band with no heading and no gap either side is not drawn."** Kept, and generalised past the
  point of being a rule: a row *is* a gap now, so a row with nothing behind it cannot be constructed.
  §4 calls this the fourth state and says there is none.

**The structural change is that a row stands for one gap rather than for one hunk**, and it is what
makes the three forms decidable at all. A band drawn per hunk carried both an up and a down control
standing for two *different* stretches of file — the one before the hunk and the one after it — so
pressing either meant working out which. `DiffFileRow.rows(of:)` interleaves gaps and hunks in `Domain`
instead, which puts the whole rule in a pure function with a test per placement rather than in a view.

Rejected: keeping the grey band and tearing only its edges, which is the bar the review is arguing
against wearing a serrated top. Rejected: a system symbol for the glyph — nothing in SF Symbols means
*these lines are not being shown*, and the closest are arrows that read as navigation. The tear and
the glyph are the only two drawings in this app, and both are recorded in §4 with the measurement
they were drawn at.

