# The diff screen is reached through a builder the compiler makes mandatory

Design §4's continuous scroll is another feature's `Presentation` — `ClientViewerPresentation` — and
the rows that open it live in `ClientWorktreesPresentation`. A `Presentation` target may see its own
feature's `Ui` and any `Domain`; a sibling `Presentation` is exactly the edge the graph refuses, and
the rule for that case is written down: the design is wrong, not the rule.

The obvious escape is to declare the destination in the composition root, which is what the
`PairedMac` link already does. **It does not work here**, and the reason is recorded two entries up:
a split view claims the destinations declared *inside its own columns*, so a `navigationDestination`
that lives only in the root is one a sidebar row inside the split view never reaches. That is the
defect this app shipped for eight releases, arriving through the door built to stop it.

So the declaration stays inside the worktrees module and only *what it builds* comes from the root:
`WorktreeSidebarScreen` and `WorktreeSplitScreen` are generic over the view a row opens, and the
builder is a **required initialiser parameter**. A row that leads nowhere now fails to compile, which
is a stronger guarantee than the comment this project relied on while it was shipping one — and the
snapshot suites pass the *real* diff screen rather than a stand-in, because a picture of a stub
asserts that a stub leads somewhere.

The cost is two generic view types. `WorktreeSplitScreen.sidebarWidth` had to move with it — a
generic type may hold no static stored property — and it went to `WorktreeSidebarView`, which is
where a fact about that row's width belongs anyway.

### And the first baseline of the pushed screen photographed a spinner

`WorktreeDiffScreen` loads from its own `.task`, so the suite that pushes it was racing its own
shutter: the recording came back as a progress view on an empty screen, which is both
non-deterministic and an assertion that a row leads to a spinner. The viewer model is loaded
*before* the render now, by a helper the two screen suites await, and what those baselines hold is
the diff. The sidebar suite was already `.serialized` for the same class of reason; the split suite
now is too.

### The name travels with the identifier, because the same defect tried to come back

An adversarial read of the wiring, before it merged, found 0.1.0's iPad defect reappearing through
the mechanism built to prevent a *different* one.

The builder is written in the composition root, inside a `navigationDestination` closure that is
re-evaluated and **builds a new `ClientWorktreesModel` every time** — while the screen below pins the
first one and is the only thing that loads it. The first version of the builder resolved the title
itself, from the local the root had just constructed. That model has read nothing, so
`displayName(of:)` falls through to its fallback and **every worktree would have opened titled *This
worktree*** — which is word for word the entry three above this one, in a new place.

So the closure takes `(WorktreeID, displayName)` and the screen that holds the loaded model resolves
the name. The root is handed the answer rather than the means to compute it wrongly.

**No test kind here would have caught it.** A snapshot constructs one view value with one model that
was loaded before the render; the defect needs a *second* evaluation with a fresh instance, which is
the same thing the entry above says about pinning. It was found by reading the wiring end to end,
which is the one review this repository has now recorded twice as the only thing that finds this
class — and 0.1.0's lesson was to budget for exactly that pass and not let it grade work it did.

