# Four points of list margin is one character of directory, and it was not stable

§3's row is a head-truncated path at the edge of what fits, which is what the frames measure it as:
about 284pt for 33 characters. Inside the iPad's split view the same layout rendered twice with the
list's own horizontal margin at two different values, and the four points moved the truncation by one
character — a red suite that nothing in the diff explains, which is this repository's second locale
trap in shape if not in cause.

The row inset is stated once and the list's own content margin is pinned to zero underneath it. What
that buys is a column whose available width is a fact rather than a measurement, which a row this
tight has to have.

