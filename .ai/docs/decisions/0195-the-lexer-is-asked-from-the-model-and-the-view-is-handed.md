# The lexer is asked from the model, and the view is handed the answer

Highlighting could have lived in a `.task` inside `DiffFileContent`, and the lazy stack would then
have given `SPEC.md` §10's "highlight the visible file first" for free — a section that is not
materialised is a file that is not lexed.

It is in `ClientViewerModel` instead, and the reason is what a test can reach. `ClientViewerUi` has
no test target at all, and a `.task` does not settle inside a synchronous snapshot render — so the
one treatment that changes every row of every file would have been coloured in the app and plain in
every baseline, which is this project's own dead-control shape with the colours instead of the
control. Handed in as a value, the view is photographable and the orchestration is a unit test.

What that costs is re-deriving the two rules the lazy stack would have given: the model steps over
every collapsed file, and it starts from the position the scroll last reported and wraps. Both are
asserted.

**The cache key gained a seventh part in 0.4.2 and the reason has now been exercised.** `SPEC.md`
§10's key is six; the seventh is the line numbers, because a hunk expansion grows the string being
lexed while `contentHash` — a fact about the *file* — does not move. What the entry does on an
expansion is keep drawing until the wider answer lands, which is the same "upgrade in place" the
first lex uses and is why nothing flashes back to plain.

**`pointSize` stays in the key and over-invalidates on purpose.** Nothing in what the lexer returns
is measured at a size, because its font is dropped — but §10 already discards every cached row height
when the code size changes, so a re-lex rides along with a relayout that was happening anyway.

