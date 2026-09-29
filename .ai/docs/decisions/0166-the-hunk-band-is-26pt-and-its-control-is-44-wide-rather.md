# The hunk band is 26pt and its control is 44 wide rather than 44 tall

*(1 September 2026, 0.6.0)*

The review's fourth fault is inverted weight: a 43pt full-bleed grey slab standing for two lines of
code drawn at 13.7pt. Rule 3 takes the band to 26pt and the code rows to 18.

The band was 43pt **because the expand control set its height** — "the band grows to 44pt only where
it carries a control", and the alternative that entry rejected was a hit area larger than the row it
is drawn in, which overlaps the code above and below and turns a missed tap into an expanded hunk.
The review draws a 26pt band with an expand chevron in it and does not say what happened to the 44pt,
which is the one place it argues against itself: its own eighth fault is a 21pt tap target being
"well under the 44pt minimum".

Resolved by buying the area horizontally: **44pt wide in a 26pt band**, which is the trade the file
header's viewed toggle already made for the same reason. It is a departure from the 44pt square and
from the review's drawing both, and it is here so that a later measurement can contradict it. The
same change makes every band one height whether or not it carries a control, so a file no longer
changes rhythm down its length.

Rejected: a 44pt hit area overflowing a 26pt band, for the reason the original entry gives; and
keeping 43pt, which leaves the fault the rule exists to fix.

