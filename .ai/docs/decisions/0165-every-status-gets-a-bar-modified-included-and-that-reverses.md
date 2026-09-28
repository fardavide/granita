# Every status gets a bar, modified included, and that reverses "modified gets no colour"

*(1 September 2026, 0.6.0)*

The review replaces the file header's status **letter** with a 3pt colour bar, and draws three
colours: amber modified, green added, red deleted. `design.md` §3 has seven statuses and four
treatments, and gives modified **no colour at all** — "modified is four rows in five; colouring the
default case spends the palette on the thing that carries no information."

Both cannot hold. A letter can be uncoloured and still be a letter; **a bar with no colour is not a
bar**, it is a hole, and four rows in five drawing a hole is a column of gaps rather than a column.
Davide settled it: every state is reflected, and modified keeps its bar. So the palette grows a fifth
treatment rather than losing two — added and untracked green, deleted red, renamed indigo, conflicted
orange, and modified and type-changed the review's own amber.

**The amber is a literal `#C0821F`, the only one in the file**, and it is deliberately not `.orange`.
Conflicted is orange, and two statuses a reader cannot tell apart is worse than the no-colour it
replaces. The system palette had no fifth hue left that reads at 3pt against both cards.

The **letter** survives unchanged in §3's selector, where a column of letters is scannable and 3pt of
colour repeated down a 32pt row is not — but both now resolve their colour through one function, so a
rename cannot be green in one screen and indigo in the other.

