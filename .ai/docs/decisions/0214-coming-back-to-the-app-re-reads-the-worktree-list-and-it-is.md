# Coming back to the app re-reads the worktree list, and it is the answer that is aged

The spinner-beside-the-title entry above rests on both reading screens re-reading from their own
`.task`. That covers one of the two ways back to a screen and not the other: **a view that was on
screen when the app went to the background never disappeared, so it never appears again and its
`.task` never re-runs.** Davide reported it on 15 September 2026 — *"when the app stays in the
background for a while, I would expect that when I reopen it, it refreshes"* — and it had been true
since the list existed.

The sidebar screen now watches `scenePhase` and offers every phase to the model, which turns most of
them down. Four refusals, each a read that would be wrong rather than merely wasteful: the app going
away rather than arriving; a read already running (`load(trigger:)` cancels what is in flight, so a
return that did not check would tear down a read most of the way through answering the same
question); nothing ever read (that screen is showing its failure and its *Try Again*, and a read
under it is a control pressing itself); and an answer still fresh. A refused *refresh* is on the
other side of the third one and does re-read — those rows are on screen with an age against them,
and settling that age is the point.

### The threshold measures the answer, not the absence

Thirty seconds since the worktrees on screen were read, rather than thirty seconds spent away.
Backgrounding is the involuntary way back — pulling Control Center down and letting it go is one —
and a read costs a magic packet at a possibly sleeping Mac plus 5.843 seconds on the profiled five
projects. What the reader wants settled is whether what they are looking at is still true: a list
read four seconds ago is, however long the glance took, and a list read ten minutes ago is not,
whether the app was away for all of that or for two seconds of it. Timing the absence instead leaves
the second case exactly as stale, which is the case that hurts. Thirty rather than longer because an
agent lands a commit inside a minute.

### The diff screen is left out, on §10's own argument

Davide scoped this to the list. Re-reading a change set replaces every entry, drops what has been
lexed and re-fetches every batch, so doing it under a reader halfway down a scroll is the unasked-for
movement `SPEC.md` §10 forbids — the same argument that rejected pull-to-refresh there. Its
appearance read stands, because a reader arriving at the diff is at the top of it. 0.14.0's pictures
sharpen that: a file's two sides are fetched once and held, and a re-read would drop both.

### The phase check is in the view and the staleness decision is not

`ScenePhase` is SwiftUI's, and a view model that knew about it would be a `Presentation` type
reaching for a framework to answer a question about time. The `onChange` makes one call and carries
no branch, which is `swift-testing`'s rule rather than a preference: a `guard` there is a branch
nothing in this repository can drive, so the comparison travels as its answer and the refusal it
expressed became the model's first guard. **What no gate here can see is the wiring itself** — there
is no Ui test target, a snapshot photographs a screen without ever changing its scene phase, and the
model's tests call the entry point directly. That one line is checked by putting the app in the
background and bringing it back, and by nothing else.

