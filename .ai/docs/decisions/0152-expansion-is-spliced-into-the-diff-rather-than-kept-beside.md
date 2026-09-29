# Expansion is spliced into the diff rather than kept beside it

`SPEC.md` §8 makes `/lines` stateless on purpose: one parameter cannot express "hunk 2 expanded up
and hunk 5 expanded down", so the Mac hands over raw lines and holds no position. The obvious
reading of "the client owns expansion state" is a structure beside the diff saying how far each hunk
has grown. **This does not do that.** Splicing produces a wider `Hunk` — new bounds, new counts, the
context lines in file order — so "is there anything left above this one" is answered by the hunk
itself and cannot drift from what is drawn. The control disappears the moment the gap it opens is
closed, without anything having to keep the two in step.

Three things fell out of building it, and each is asserted:

- **A zero count is not an empty range at the line it names.** git writes `+c,0` for a hunk that adds
  nothing, where `c` is the last line *before* the change on the new side rather than the first line
  of it. Measuring either window from `c` hands back a line the hunk is already drawing. The same
  rule makes a wholly deleted file answer "nothing to expand" on both sides, which is correct — the
  hunk already holds every line there is.
- **The offset between the two sides is not one number.** Above a hunk it is the distance between the
  two ranges' first lines; below it, between their last. A hunk that adds three lines leaves the
  sides three further apart on the way out than on the way in, and using one offset for both would
  produce a gutter that is plausible and wrong.
- **Every window is read from the new side.** A context line is by definition the same on both, the
  reader is reading the working copy, and the one case with no new side has no gap to ask about.

**Twenty lines a press, stated rather than settled.** At §4's 11pt that is about a third of a phone
screen — enough to see what encloses a change, little enough that the line the reader was on is still
on screen afterwards. A press that scrolls past a full screen of new context loses their place, which
is the thing expansion exists to protect.

**A refused expansion is reported where a refused batch is not**, and the difference is what the
reader did. A batch is fetched on their behalf while they scroll, so losing one leaves placeholders
the next scroll asks about again. An expansion is a control they pressed, and a press that leaves the
hunk exactly as it was is a control that did nothing — so it gets an alert of its own, with its own
sentence, rather than sharing the mark's.

**Two presses inside one round trip would splice one window twice**, and that is recorded rather than
guarded. Both compute their window before either lands, so both ask for the same lines and both
splice them. The guard is a branch no test kind here can drive — it needs two calls genuinely
overlapping, and therefore a fake that holds a request open — and an untested branch is worse than a
defect whose symptom is twenty context lines appearing twice with the gutter numbers saying so. It is
on the device afternoon's list, which is where it can be seen.

