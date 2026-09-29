# Three things §7 drew that are built differently, and one it drew that is not built

**The iPad's review column is 320pt rather than 360.** The design's 360 takes the code pane from 874pt
to 834 when the review opens. `SPEC.md` §10 caches every measured row height on `availableWidth` and
requires a `(fileID, lineIndex)` anchor capture across any width change — so 40pt of list costs a
reflow of the file the reader is looking at, on a control they pressed for a different reason.
Matching the tree's own 320 moves the code pane by exactly zero, which is the same argument
`DiffPaneLayout` already makes for keeping the point size off the fold.

**The composer's anchor is a label rather than a `Menu`.** §7 draws a 44pt menu offering extend-up,
extend-down and shrink-from-either-end, and it is the stated remedy for a one-row miss. The controls
behind it are not built, and a menu with no items is this project's dead control — so it ships as the
44pt row saying what the comment is about, and the menu lands with the operations. **This weakens the
44pt argument above and is the strongest reason to build them next.**

**The composer's refusal state is deliberately not built**, which is the design's own instruction: it
verified that the screen loads once from its `.task` and that a reader cannot reach the retry with a
composer over it, so the state is unreachable in 0.6.1. What §7 asks for alongside — that
`ReviewCommentStore.save` be able to return a refusal so it is not retro-fitted — is **declined**. It
would add a branch no test kind here can drive, under a coverage ratchet with no slack, for a state
the design says not to build. `commentFailure` already covers the one refusal that is reachable, and
it has an alert now: a comment whose lines moved cannot be written against an anchor that no longer
resolves, and an invented anchor is worse than no comment because the agent acts on it.

**The iPad's third column was promised to focus mode** by `SPEC.md` §10 and `design.md` §5, and §7
takes it for the review. Recorded as an override rather than a conflict: focus mode is unbuilt, and
this repository already refused a real three-column split view for reasons that have not changed.

