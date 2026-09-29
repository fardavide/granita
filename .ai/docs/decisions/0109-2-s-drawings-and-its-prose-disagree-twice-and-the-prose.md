# §2's drawings and its prose disagree twice, and the prose wins both times

The frames are measured and the prose is written from them, so a conflict is normally the drawing
being right. **These two are the other way round, because in each case the drawing contradicts a rule
stated in the same document.**

**The rename sheet's footer previews the suggestion, not the branch.** Frame (c) draws *"Clear the
field and save to go back to feat/tls-pinning"* while a session summary is on screen one section
below — but the Mac resolves a display name as alias, then suggestion, then branch, then directory,
so clearing that alias would put the summary on the row and not the branch. The footer's whole
purpose is stated a paragraph above the frame: it says what the row will read after Save. A footer
that is wrong in the one case a reader is checking it is worse than no footer. So the fallback is
`suggestedAlias ?? branch ?? directoryName`, and `WorktreeRenameSubject` carries which of the three
won, because with no suggestion the sheet's section is absent and the footer has to say *why*.

**A quiet primary checkout is hidden like any other.** The grouped frame draws *"main · primary
checkout · no changes"* above a footer reading *"6 worktrees with no changes are hidden"*, which
cannot both be true. Exempting the primary was the tempting reading — §2 says the word exists partly
because that row "usually has no changes" — and it is unbuildable: §2 also draws *"Nothing to
review. All 9 worktrees across granita and aura are clean"*, and a never-hidden primary makes that
state unreachable, since every project has one. So the filter is literal, the word still earns its
place on the rows that do show, and Davide confirmed it rather than it being picked.

