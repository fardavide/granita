# The lock rule refused deletion on nearly every row, and is reversed

**Deleting a worktree never worked once**, from 0.5.0 to 0.9.0, on any worktree an agent made — which
is the only kind this product is for. Davide reported it on 5 September 2026 as *deleting a worktree
doesn't work, I think it needs to force*, and the force was already there. What was missing was the
second one.

**Claude Code locks every worktree it creates.** `git worktree list --porcelain` on this repository's
own agent worktree reports `locked claude agent bridge-cse_018cS7UJh8GG6nvTm4YTtCsK (pid 68607 …)`.
The entry above reasoned that a lock is a person at that Mac saying do not remove this, and refused
it — a rule with exactly one true instance in the wild, and it is not a person, it is the agent whose
leftovers the reader opened Granita to clear up. So the guard fired on essentially every row, which
is precisely the outcome the same entry gave as the reason for forcing at all: *a control that
refuses on nearly every row it is offered on, which is worse than not having one*. The argument was
right and it was applied to the wrong flag.

**Both `--force`s are sent now**, and the lock is stated rather than enforced. Verified on git 2.52.0
against a scratch repository: `worktree remove --force --` on a worktree locked with
`--reason "claude agent test"` exits 128 with `fatal: cannot remove a locked working tree, lock
reason: … use 'remove -f -f' to override or unlock first`; the same command with `--force --force`
exits 0 and takes the directory with it, dirty and locked. That is the whole defect and the whole
fix.

**Which leaves `WorktreeDeletability` with one refusal instead of two.** The primary checkout is
still absolute — git refuses it however many times it is forced. `WorktreeDeletionSubject` gained
`isLocked` in exchange, and the confirmation gained a paragraph after the cost: *Your Mac has this
worktree locked — Claude Code locks the ones it makes. Deleting it here goes ahead anyway.* Last
rather than first, because the cost is what is being decided and the lock is what the deletion has to
get past to do it. A reader cannot override something nobody told them about, and that sentence is
now the only thing the flag does.

**A hand-set lock goes with it, and that is the cost.** Somebody who runs `git worktree lock` by hand
gets a sentence rather than a refusal. It is the same trade the forced removal already makes with
uncommitted work: the confirmation is the safeguard, and this adds a line to it rather than a second
kind of veto.

This overrules design §6's provisional call 7, which noted the premise had moved and deliberately did
not act on it. Issue [#52](https://github.com/fardavide/granita/issues/52) still has not been sent,
so the sentence is one more provisional call for Design to overrule, listed there with the rest.

---

