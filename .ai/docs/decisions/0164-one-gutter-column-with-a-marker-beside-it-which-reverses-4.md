# One gutter column with a marker beside it, which reverses §4's rejection of exactly that

*(1 September 2026, 0.6.0)*

The diff design review's first fault is a correctness bug: the gutter held the **new**-side number
alone, so a deletion — which has no new-side number — drew an empty column. A reader who wanted to
say "line 6 is wrong" had nothing to point at on the one row kind that says something was removed.

The fix the review draws is one column carrying whichever side the row is on, and `design.md` §4 had
**rejected that by name**: "it looks like one sequence and is two, so scanning it produces wrong line
numbers with total confidence." That rejection assumed nothing else on the row said which side you
were reading. The review's rule 2 adds the thing that does — a 12pt `+`/`−` column at full
saturation — so the objection does not survive its own premise. **The two rules only work together**,
and adopting either alone would be worse than today: a marker without the number leaves the bug, and
the number without the marker is the ambiguity §4 named.

Davide adopted both. What it costs is about three characters of code per row, and the review's answer
to that is the one worth keeping: the row those characters came from was *already* cut off at the
bezel without saying so, so they were never being read.

**It departs from `SPEC.md` §10** — "gutter with old and new line numbers" — and the departure is
recorded here rather than assumed, because it is the second half of one that was never written down:
the phone has shipped a single column since 0.2.0 and no entry says so. Both halves are recorded now.
Rejected: two columns on the phone, which §4 measured at 41 characters and called a keyhole; and the
marker alone, which leaves the bug it was meant to fix.

The iPad loses its second column with the phone. §4 argued that both columns are "the whole reason
the phone can afford to drop one"; with the interleaved column that argument has nothing left to
support, and the review's own iPad frame draws one 44pt column.

