# The review lives in the phone's user defaults, and #64 is where it should live

Davide's call on 3 September 2026: persisted on the phone now, with an issue to move it to the Mac.

**Persisted rather than held in the model**, because a review is written over as long as it takes to
read a change set and iOS ends a backgrounded app whenever it likes. Comments lost to a phone call
are an afternoon lost, and the thing they were written on is the one thing the app cannot re-derive.

**Keyed per worktree**, because that is what a review is of. Two agents in two checkouts of one
project are two reviews.

The Mac is the right home — it survives a new phone, it is where the worktree is, and `SPEC.md` §9's
`Store` protocol was written for exactly this growth — and it is a wire change with new routes and a
contract version, so it is [#64](https://github.com/fardavide/granita/issues/64) rather than this
slice. **Nothing here has to be rewritten when it moves**: `ReviewCommentStore` is a `Domain`
protocol, and the Mac's version is a second conformer and one line of the composition root.

