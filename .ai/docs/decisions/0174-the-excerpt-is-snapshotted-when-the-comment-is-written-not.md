# The excerpt is snapshotted when the comment is written, not resolved when it is exported

A comment carries the path, the span and the quoted rows as they were on screen. The obvious
alternative — hold the anchor and re-read the diff at export time — is wrong for the one reason this
feature exists: the agent is about to change exactly those lines, so a quote resolved later shows its
reply rather than the reader's question. It also keeps a comment sendable after its file has left the
change set, which is what happens when the agent reverts something between the note and the paste.

**A run that is entirely deletions is named on the old side and the document says so.** Everything
else is named on the new side, because the agent opens the working copy and "line 12" has to mean the
line it would find; reporting a new-side number for lines that exist nowhere in it would send the
agent to whatever now sits there. It is said only in the case that needs it, so the ordinary comment
stays quiet. *The wording and its placement changed with §7's return, below — it is a line under the
path rather than a suffix on it.*

