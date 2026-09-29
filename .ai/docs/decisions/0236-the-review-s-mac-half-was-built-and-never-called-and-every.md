# The review's Mac half was built and never called, and every change is offered to the Mac now

0.15.0 gave the phone's review model two entry points: one reads the review settings, the other
merges this phone's comments with the Mac's copy and sends the merged review back. **Nothing called
either.** So every copy began with the built-in opening line and letter labels, whatever the reader
had saved, and no review ever left the phone. The model tests stayed green throughout, because each
method worked when a test called it. What was missing was the one line in the screen that makes the
call. Both now run each time the review opens, as a sheet or as a column. They run at that moment
rather than when the diff loads because on the iPad the settings sheet sits over the diff, and
closing it re-runs nothing underneath.

**Turning the merge on exposed a second defect, and it is why the phone now pushes on every
change.** The merge is a union. It cannot tell a comment deleted on this phone from one this phone
never had, and the only push happened when the review opened. So *Clear* after copying left the Mac
holding the whole review, and the next open merged it back. Every save, delete and *Clear* now
offers the review to the Mac without the reader waiting. The pushes run one at a time in the order
they were made, because the Mac keeps whichever arrives last, and two racing pushes could leave it
holding a review the reader had already cleared.

**One known gap, accepted by Davide.** A *Clear* made while the Mac cannot be reached is refused.
The Mac keeps the old review, and the next open merges it back. Closing that gap needs deletions
carried as deletions, as tombstones or as a version the Mac can compare, rather than as absence.
That is a wire change, not a fix to this model.

> Rejected: ship only the opening-line fix and leave the merge uncalled until deletions travel.
> It was the smaller change. Davide chose to have the review reach the Mac now, with the gap above
> named rather than hidden.
