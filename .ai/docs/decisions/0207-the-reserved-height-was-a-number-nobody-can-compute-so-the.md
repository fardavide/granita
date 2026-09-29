# The reserved height was a number nobody can compute, so the skeleton is short and the arrival moves

*(13 September 2026, 0.12.1)*

Design §9 was built on one premise — *the box keeps every point of its height* — and 0.12.0 shipped
it: an unarrived file reserved `max(1, estimatedLineCount)` rows, so nothing moved when the diff
landed. Davide read it and reversed the premise:

> *"We cannot predict the size of the expanders. So it actually doesn't match correctly the final
> height."*

**He is right, and the arithmetic was never available.** `estimatedLineCount` counts *diff lines*.
A drawn file is diff lines **plus a torn expander wherever the diff skipped something** — 44pt each,
about two and a half rows at the phone's code size, one above the first hunk, one below the last and
one between every pair. `DiffFileRow.rows(of:)` decides how many, from hunks the phone does not have
yet, and nothing on the wire reports them. So the height was short by an amount that could not be
known, on every file with more than one hunk in it. A 300-row file was reserving 5,400pt in order to
land somewhere else.

**A tall wrong box is worse than a short honest one.** It spends most of a screen asserting a
position it will not keep, and the correction it then makes is exactly the jump the reservation was
for. So `reservedRows` is capped at four for an unarrived file — `min(estimate, 4)`, capped rather
than fixed, because a skeleton taller than the file it stands for is the same lie reversed.

### What holds the screen still now

**The rule that was always underneath the reserved height, rather than the height itself**:
`ContinuousDiffLoading` never fetches behind the reader, so a file whose height changes is at or
below them and never above. The reservation was one way of keeping the screen still. Motion is the
other, and it is the honest one once the number the reservation was built on is known to be wrong.

So the arrival is animated, at the two sites §4's own rule names: the skeleton fades out where the
code fades in, and the **stack** — the container that lays the movement out, not the section inside
it — carries `Animation.disclosure` keyed on readiness. That key was previously and deliberately
excluded, with a comment saying so: *"keyed on nothing but the collapse flags, so a diff arriving
still lands without dragging the scroll around."* That was correct while the swap moved nothing. It
moves something now, and a height that changes without moving is the jump §4 exists to prevent
arriving from the one direction that had been exempt.

### And the sticky sentence went with the height that justified it

§9 made the first row sticky inside its own box, offset by the box's intersection with the viewport,
so a reader sitting inside 5,400pt of reserved card kept the words under the pinned header. A
four-row card has no inside to sit in. The rule, its `visualEffect` and the `nonisolated` static it
needed are all gone; `DiffFileHeader.height` keeps its `nonisolated` spelling, which costs nothing
and was worth having anyway.

