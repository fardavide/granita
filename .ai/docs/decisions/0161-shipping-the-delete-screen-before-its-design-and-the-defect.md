# Shipping the delete screen before its design, and the defect that found

**The `design-handoff` rule is that no pull request touching a screen opens before its frames
exist.** This one did, on 28 August 2026, because Davide asked for it in as many words: he was
close to his weekly limit, wanted the feature usable, and wanted the design round trip to happen
afterwards and correct it. So the departure is his call, taken with the cost written down rather
than by quietly forgetting the rule.

**What makes it affordable is that the treatment was built to be overruled.** Thirteen calls were
made without authority; every one is listed in [`design.md`](../design.md) §6, each is a single file or
a single modifier, and the prompt that will overrule them is
[issue #52](https://github.com/fardavide/granita/issues/52), written before any of the screen was
built. The issue exists so the ask survives the week rather than being reconstructed from the code
that guessed at it.

**The treatment was chosen by a panel rather than picked.** Four independent proposals were written
against §2 and the constraint list, three judges scored them on separate lenses — constraint
compliance, reader harm, and how cheaply a returned design could rip each one out — and the
synthesis took one as the spine and grafted five ideas from the runner-up. Two of the four proposals
were lost to schema failures and the panel judged two; that is worth knowing when reading the
verdict, and did not change which of the two won, because the loser was eliminated on confirmed
fatal flaws rather than on ranking.

### The panel found a control that did nothing, and no test here could have

`confirmDeletion()` read its subject back off `model.deleting`. Dismissing a SwiftUI alert writes
`false` through its `isPresented` binding, which clears that property **synchronously**, while the
button's own `Task { }` body does not run until a later turn on the main actor. So by the time the
work started there was nothing left to delete, `guard let subject = deleting else { return }`
returned, and **the Delete button destroyed nothing at all** — with the whole suite green, because a
raster does not include an alert and cannot press a button, and the model test drove the method
directly rather than through the binding.

That is this repository's own oldest defect arriving through a new door: a control that looks
finished at every layer, with the gap between two of them. The fix is `confirmDeletion(of:)` taking
the subject the confirmation was presented with, which is also the stronger guarantee — what is
destroyed is what was confirmed, never whatever the model happens to hold when the tap lands. The
regression test drives the exact ordering: begin, cancel, then confirm.

**It is the reason the affordance is not in the swipe.** A trailing swipe begins the way an
imprecise vertical scroll does, and iOS hands the *first* trailing action the full swipe — so a
destructive third action there is one over-committed thumb away from destroying work that was never
committed. A long press requires the finger to stay still, which is the one thing scrolling never
does, and leaving the swipe alone keeps its full swipe meaning Pin. The open question about whether
a full swipe may destroy a worktree is therefore answered structurally rather than by tuning a flag.

### Two things bought, and what would delete them again

**`WorktreeWriteRefusal`**, because the same `ApiFailure` means two different things: an unreachable
Mac leaves a rename exactly as it was, so *trying again usually works* is true, and leaves a deletion
in a state this phone cannot describe, where the same sentence is a claim nobody can make. Without
the operation travelling beside the failure there is no way to route the third message. If the design
comes back saying one message is enough, that type is **deleted**, not kept.

**`removing` is a set rather than one identifier**, because confirming one deletion, swiping a second
and confirming that too is reachable at LAN speed — and with an optional the second answer would
clear the first one's mark and put a row back on screen that is still going away. The `defer` that
clears it fires on every path including both failures; a `defer` that fired on only one would leave a
row dimmed and inoperable for the rest of the session, which is what the two identically-rasterising
refusal baselines exist to catch.

### Rejected, so it is not re-proposed

`.onDelete(perform:)` with `.deleteDisabled(_:)` is the cheapest-looking option and is wrong twice:
it hands back an `IndexSet` where this codebase requires the typed `WorktreeID` wrapper through every
signature, and `deleteDisabled` renders as a swipe that reveals nothing, which is a control that
looks operable and does nothing.

