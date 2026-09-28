# A comment is addressed by the numbers its rows carry, never by where they sit

An anchor has to survive two things: a hunk expansion, which splices twenty lines into the middle of
a file, and the screen re-appearing, which re-runs `load()` and replaces every hunk. An offset into
the drawn rows survives neither.

Old line numbers rise monotonically down the old side and new ones down the new side, so the pair
`(oldNumber, newNumber)` is unique within a file and unmoved by both: a deletion is `(11, nil)` and
stays `(11, nil)` however much context arrives above it, and spliced context arrives carrying real
numbers. That pair is `DiffLinePosition`, and a comment stores the pair at each end of its run.

**A row with no number on either side therefore cannot be an end of a selection**, and that costs
nothing because design §4's gutter draws no figure for such a row — there is nothing to tap. A
selection still *spans* one and the quote carries it verbatim.

**The first version of this rule named the wrong rows, and a test found it.** It said conflict
markers were the numberless case, which reads plausibly and is wrong: a conflicted working tree holds
`<<<<<<< HEAD` as literal content, so git diffs it behind an ordinary `+` and `UnifiedDiffParser`
numbers it from *that* prefix before re-tagging it by its text. The `.conflictMarker` arm of
`occupiesOldSide` is unreachable. So the markers stay addressable, which is the outcome worth having
— a conflict is what a reader most wants to point at — and the one genuinely numberless row is
`\ No newline at end of file`, of which a hunk holds two whenever a trailing newline is added.

**The same discovery moved the quote's markers off the kind and onto the numbers.** Re-tagging throws
the prefix away, so a `+`/`-`/space chosen by `DiffLineKind` would put the wrong one on every
conflict marker. Which sides a row occupies survives the re-tagging and says the same thing.
*Superseded by §7's return, below: the excerpt carries no diff markers at all.*

