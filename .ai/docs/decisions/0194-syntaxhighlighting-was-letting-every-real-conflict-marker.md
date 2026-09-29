# `SyntaxHighlighting` was letting every real conflict marker through to the lexer

The domain half of highlighting landed in 0.4.2 and nothing called it until now. Its own doc said
that reading a line's side off the numbers the parser wrote "is what keeps `<<<<<<<` out of the
string the lexer reads", on the belief that a conflict marker carries no number on either side.

**It carries both.** A conflicted working tree holds `<<<<<<< HEAD` as literal content, so git diffs
it behind a `+` and `UnifiedDiffParser` numbers it from that prefix *before* re-tagging it by its
text — which `status.md` had already recorded from the other direction in 0.7.0, where it made
`occupiesOldSide`'s `.conflictMarker` arm unreachable. The suite did not catch it because its
conflict fixture used unnumbered markers, which is the case that cannot occur.

So the string handed to the lexer would have opened with `<<<<<<< HEAD` on exactly the files a reader
most needs to read, and a lexer handed one mis-lexes everything after it. The kind is now excluded
alongside the numbers, with a test that uses the marker the parser actually produces. Nothing shipped
with the defect — it was found by writing the first caller.

