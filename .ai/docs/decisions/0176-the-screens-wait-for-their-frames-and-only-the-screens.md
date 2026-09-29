# The screens wait for their frames, and only the screens

The composer, the way a line is chosen, the button that appears once a review exists, the overall-note
prompt with its *Skip*, and the copy are all reader-facing and none of them is drawn, so
`design-handoff`'s rule applies in full: no pull request touching a screen opens before the frames
exist. The prompt was written on 3 September 2026.

**What shipped alongside is everything a frame cannot be authoritative about** — the anchor, the
selection, the document, the store, its conformer, and the model's whole comment half — which is that
skill's own instruction rather than a way around it. It is the same split 0.5.0's worktree deletion
used, taken the other way: there Davide chose to ship the screen ahead of its design and pay for it
in thirteen recorded calls; here he chose to wait.

**The pasteboard is not in this half, and that is a coverage call as much as a scope one.** Copying
is I/O and belongs behind a seam its `Domain` owns, the way the Mac's `SystemGestures` does — and the
Mac's conformer had to be added to `UNREACHABLE_FILES` to get there, which is a scope redefinition
rather than a commit. Adding a seam for a button nobody can press yet would spend that conversation
early and blind. It lands with the button.

