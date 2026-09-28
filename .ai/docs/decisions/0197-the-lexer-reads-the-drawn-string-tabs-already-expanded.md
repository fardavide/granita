# The lexer reads the drawn string, tabs already expanded

A colour comes back as a range into the string that was lexed and is applied to the string
`DrawnDiffLine` produces. A tab is one character in the first and two, three or four in the second,
so every colour after one would have landed partway through the wrong token — the same trap the word
diff hit in 0.4.2, where a segment's tabs were expanded from column zero of the *segment*.

`HighlightSource` therefore carries `MonospacedGrid.expandingTabs` output rather than the raw line. A
tab is whitespace to every lexer, so this costs the lexing nothing and saves a second mapping between
two spellings of one line.

The row still checks the two lengths agree before applying a background, and that guard is not
belt and braces: highlight.js round-trips through HTML and decodes entities on the way back, so a
file containing `&amp;` literally can return a line shorter than the one it was given. That row draws
plain and the rest of the file keeps its colours.

---

