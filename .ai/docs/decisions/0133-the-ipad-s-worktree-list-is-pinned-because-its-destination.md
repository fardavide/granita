# The iPad's worktree list is pinned, because its destination was reading a model nobody loaded

`WorktreeSplitScreen` held its model as a plain property. The composition root presents it from
inside a `navigationDestination` closure that **builds a new `ClientWorktreesModel` on every
evaluation**, and the sidebar underneath pins the first one in `@State` and is the only thing that
loads it. So the rows came from a loaded model and the destination declared beside them resolved the
chosen row's name against whichever instance the last evaluation had produced — one that had read
nothing, whose display name is therefore the fallback word. **Every worktree opened on the iPad was
titled *This worktree*.** The phone was unaffected: it branches to the sidebar screen, which pins.

The screen pins now, the same way the sidebar and the discovery screen already do and for a stronger
reason — for them a swapped instance is a task driving a discarded object, here it is two halves of
one screen disagreeing about what is on it.

**No snapshot kind can see this, and that is worth stating rather than working around.** A picture
is taken of one view value built once; the defect needs a second evaluation with a different
instance, which a test that constructs the view cannot produce and a wrapper that forced one would
race the raster it is trying to assert. What the suite gained instead is a baseline of the fallback
itself — a chosen worktree that is no longer in the list, which is the one case *This worktree* is
legitimately the answer, since an agent removes a checkout every day and one can stop being in the
list between the tap and the push. It is photographed so that word is a state somebody chose rather
than one nobody could see.

