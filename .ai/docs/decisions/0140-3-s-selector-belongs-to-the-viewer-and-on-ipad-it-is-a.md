# §3's selector belongs to the viewer, and on iPad it is a column inside the diff rather than a third column of the split view

Design §4's iPad is "three columns at 320 / 320 / 554", and the obvious build of that sentence is a
three-column `NavigationSplitView`: worktrees, then files, then code. It is not what shipped, and the
reason is the layer graph plus the one thing this repository cannot check.

**The selector is the viewer's**, not the worktree list's. It navigates the diff, it reads the same
change set the scroll is drawing, and `ClientViewerModel`'s doc comment has said since 0.2.0 that the
scroll, the file header and §3's selector are three views onto one question. A third split-view column
would have to be composed where both features are visible, which is `ClientAppMain` — and a `Main`
module holds wiring and nothing else, which is the argument that made `WorktreeSplitScreen` a screen
rather than four lines in the root.

**And a real third column means selection-driven navigation**, because a `navigationDestination`
produces one view and not two columns. That would turn the sidebar's rows from value-based links into
a `List(selection:)`, on the one navigation path this app has proven — the path that broke twice in
0.1.0 in ways only a photograph could show, and that carried a row leading nowhere for eight
releases. **There is no iOS UI test target**, so the only check on it is a thumb, and a thumb is what
this machine does not have.

So `WorktreeDiffScreen` composes it: a drawer on the phone, and in a regular width an `HStack` of the
selector at 320pt, a divider, and the code. Inside the existing split view's detail column that is
320 + 320 + 554 at iPad Pro 11" landscape — §4's measure exactly, photographed rather than argued.

> Rejected: the three-column split view, above. Rejected: putting the selector in
> `ClientWorktreesPresentation` so the split view could own it — that target may not see a sibling
> `Presentation`, which is the same edge that made the diff screen's builder a required parameter.

### Two things the handover asked for that did not happen, and both are Davide's to settle

**`NoWorktreeChosenView` stays.** The note that opened this slice said §3 "deletes the detail column's
*Choose a worktree* the way §4 deleted the not-ready screen". Design §2 says the opposite in as many
words — "the empty detail column is an unavailable-content view, the same control as every other empty
state in the app" — and it gives the reason: a blank column reads as a screen that failed to load.
Under the composition above the detail column is still empty until a worktree is chosen, so deleting
that view would leave exactly the blank §2 forbids. **The `design` skill's rule for prose against
prose is to ask rather than pick**, so this is asked rather than picked.

**The doubled `navigationDestination` stays doubled.** Its comment predicted it would collapse "the
day §3's file selector gives the detail column something of its own to show", and that day has not
arrived: the detail column shows the selector *for a chosen worktree*, so the tap that chooses one is
still claimed by one of two containers and which one cannot be settled on a machine with no finger.
Removing a declaration to find out is how this app shipped a row that did nothing.

