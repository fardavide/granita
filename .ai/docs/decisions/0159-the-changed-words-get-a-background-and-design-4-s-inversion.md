# The changed words get a background, and design §4's inversion is reverted to the specification

Design §4 tested "two nested backgrounds behind mono text" and returned **fits, not as drawn**: in
light at a 3× alpha ratio yes, in dark no, because the row tint already needs 16% to be visible
against black and there is no headroom above it. So the review inverted the emphasis into the text —
unchanged runs on a changed line down to `.secondary`, the changed run at full-strength label — and
that is what 0.2.0 built.

**It reads well and it spends the one property the syntax highlighter needs.** A lexer colours text.
A line whose text colour already means *this part changed* has nothing left to say `keyword` with,
and `SPEC.md` §10 asks for both on the same line: word-level segments **and** per-file syntax
highlighting. The review saw the edge of this — it rejected underlining the changed run because "it
collides with whatever the syntax highlighter does" — but it never drew the two together, and §4 has
no highlighting section at all.

Davide settled it on 28 August 2026: *"Changed words should have different background color, instead
of text color"*. That is not a new call so much as a return to the specification, which has said
since it was written that word-level highlighting goes on "as a stronger background on the changed
spans over the line level add/remove background".

**What survives from §4 is the argument rather than the number.** "Stronger" is a ratio, and that is
the part that was right. Two translucent layers do not add, they composite — `1 - (1 - t)(1 - s)` —
so a segment drawn at the fixed 28% the review measured reads as a *different* multiple of the row in
each appearance, which is the drift it rejected the treatment for in the first place. So the ratio is
what is stated and the alpha is solved from it: the changed run lands at three times the row's own
tint in both appearances, which is about 22% in light and 38% in dark. One number written down, two
derived, and they cannot come apart.

**The line is now drawn once rather than run by run, and that fixed a tab defect nobody had hit.**
The old treatment built one `Text` per segment and expanded each segment's tabs independently, so a
tab in a later run measured from column zero of that *run* rather than of the line — `if\ttrue` split
after `if` drew `if    true` where the grid says `if  true`, and every column after it was wrong
against the gutter the scroll was measured from. Tab expansion now carries the column between runs,
`MonospacedGrid` owns that in one place, and the property that the runs joined equal the whole-line
expansion is asserted rather than assumed. Reachable in any tab-indented file — Go, Make — with a
word-level pair on a line with a tab in the middle of it.

**The ranges are characters, not columns.** An ideograph is one character of the string and two
columns of the grid; a background is applied over the string. The two counts are both right and they
are not interchangeable, so `DrawnDiffLine` names which one it is in.


---

