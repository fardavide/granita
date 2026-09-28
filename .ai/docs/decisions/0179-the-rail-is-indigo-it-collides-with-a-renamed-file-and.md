# The rail is indigo, it collides with a renamed file, and neither of them is load-bearing

`FileStatusLetter` already returns `.indigo` for a rename, and its own doc says green, red, indigo and
orange are the four the palette has. There is no fifth hue.

Shipped anyway, and recorded rather than resolved: the two are different shapes in different places —
a 3pt vertical rail in the gutter's leading inset against a 3pt horizontal status bar in a file header
— and **neither carries its meaning by colour**. The rail's position and length are what say *a
comment, this long, here*; the status bar's letter is what says *renamed*. Both survive greyscale,
which is the test §4's marker column was added to pass.

**The colourblind-safe rail the design specifies is not built, because the palette it belongs to is
not built.** `SPEC.md` §10 asks for a blue-and-orange toggle and nothing in the repository implements
one — no setting, no enum, no alternate colour. §7's dark ochre is recorded as waiting on that slice,
and it would collide with `fileStatusAmber` when it arrives, which is worth knowing before it does.

