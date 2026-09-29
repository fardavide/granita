# The stale row inserts 44pt into a file, and it is legal for one reason only

A comment whose anchor no longer resolves has no rows to sit beside, so it cannot keep a rail. §7
gives it a 44pt amber row under its file's own header — which inserts height into a file, and the
no-reflow rule forbids exactly that.

It is legal because **staleness can only become true when the diff is re-read**, and a re-read
re-measures the document from the top. It cannot land under a finger. Today the screen loads once from
its `.task` and the only other route in is a retry from the failure state, so the row can only appear
across a relaunch.

**If a refresh is ever added — and `SPEC.md` §10's live updates are exactly that — this row becomes
illegal and the mark has to move into the review sheet alone.** The design says so itself, and it is
written into `StaleCommentRow`'s own doc comment so the next person to touch the refresh path finds it.

