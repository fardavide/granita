# The export is plain text, and that reverses what was built two days earlier

The first implementation emitted Markdown — `# Review of <worktree>`, `## path:span`, a fenced `diff`
block — reasoning that the reader was about to paste it into a chat. §7 overturned it and the argument
is better: the destination is a terminal on the Mac the phone is lying beside, the audience is an
agent rather than a renderer, and heading syntax is something that has to be stripped before it can be
acted on. What replaced it is the shape the text already had.

Four decisions inside it are the design's: full repository-relative paths, document order, the excerpt
quoted with `> ` from a snapshot taken when the comment was written, and no trace at all of a skipped
note — because an agent reading a placeholder treats it as an instruction to go and find one.

**The excerpt lost its `+`/`−` markers with it**, which is a straight reversal of the entry above.
The frame draws none, and the reason holds up: what a comment is about is those lines, which side they
are on is what the numbers beside the path say, and `+ func awaitItem()` is a string that appears in
no file — an agent that greps for it finds nothing. The one row that keeps a prefix is
`\ No newline at end of file`, which is git's own annotation rather than a line of the file and reads
as a sentence of English in the middle of some code without it.

**One line in the document is ours rather than the design's, and it is flagged as such.** A run named
on the old side gets `(these lines were removed — the numbers are from before the change)`. §7's own
example could not surface the case: it quotes four additions and one deletion whose comment text
happens to say it was deleted. A run that exists nowhere in the working copy sends an agent opening
the file at those numbers to whatever now sits there. It borrows the idiom the stale line already
established rather than inventing a second one, and it is one line in the case that needs it.

