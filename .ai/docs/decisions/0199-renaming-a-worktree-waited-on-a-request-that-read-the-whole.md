# Renaming a worktree waited on a request that read the whole Mac

Reported in the same message: *the rename works very weirdly, the bottom sheet doesn't close and the
rename takes a while*. Two defects compounding, one on each side.

**The Mac answered a one-line write by rebuilding everything.** `PATCH /v1/worktrees/:id` wrote the
alias to the JSON document and then called `registry.worktrees(inProject: nil)` to find its own row
in the result — which builds a change set (`status`, `diff`, a batched `hash-object`) for every
worktree of every enabled project. That is the same work `/v1/worktrees` does, and the model's own
comment already put it at over two minutes on ten real repositories. The registry now has a
`worktree(_:)` that describes one checkout from the `Resolved` the route already holds, so a rename
costs one change set instead of N.

**And the phone waited for it before doing anything at all.** `rename(_:to:)` awaited the round trip
and only then put the sheet down, so a modal sat over a list the reader could not see for the length
of that request — and a refusal could not present its alert, because the sheet was still up in front
of it.

**Renaming and pinning are optimistic now; deleting stays pessimistic.** The asymmetry is the one
this repository already recorded and never implemented: an alias and a pin are entries in the Mac's
own document, so a failed write shows the wrong name until the next read, which a reader notices and
can repeat — while a failed deletion shows a worktree that still exists as destroyed, which nobody
goes looking for. `write(_:to:)` applies the patch, rearranges, and then replaces the row with the
Mac's answer or puts back exactly what was there. The refusal alert's existing words hold either way:
*the row is still as it was*.

**Which makes the phone resolve a display name for the first time.** It was resolved once, on the
server, so both apps agreed — and a second spelling of `alias ?? suggestedAlias ?? branch ??
directoryName` is a row that reads one thing until the next read and another afterwards. So the rule
is `Worktree.applying(_:)` in `CoreDiffDomain`, and the answer still replaces the guess when it lands
rather than being assumed to match it. The suite's fake Mac keeps its own separate spelling on
purpose: a fake that called the production rule would be asserting it against itself.

**The row is written before the request rather than after the answer**, so a worktree that has left
the list is refused without a round trip, and one that leaves *while* a write is in flight is left
alone — putting the answer back would undo a deletion the reader confirmed in the meantime.

---

