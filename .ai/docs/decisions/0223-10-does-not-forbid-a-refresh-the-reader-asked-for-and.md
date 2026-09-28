# §10 does not forbid a refresh the reader asked for, and reading it as one cost the diff four releases

The diff screen shipped without a way to re-read itself, and the reason recorded in `design.md` was
`SPEC.md` §10: re-reading replaces every entry, drops what has been lexed and re-fetches every batch,
and doing that to a reader halfway down a scroll is the movement the rule forbids. That argument is
sound about a read **nobody asked for** — which is why the read on returning to the foreground is
still excluded — and it was then carried, in one clause, to the reader's own gesture as well.

**The clause was the same category error the `design` skill already had a paragraph about.** §10
forbids content moving *unasked*; it has never been an argument against a layout that moves because
the reader pressed something, and that had already been written down after 0.5.2 shipped a half-fix
for the disclosure animations on the strength of the same misreading.

**The structural form of the rebuttal is what settles it, not the interpretive one.** A pull is only
reachable at the top of a scroll. That is the position the appearance read is already allowed at, for
exactly the reason `design.md` gives — *a reader arriving at the diff is at the top of it* — so the
gesture cannot reach the state the rule is about. It also leaves §7.3's stale-comment row legal
untouched, where §7.3 had flagged that a refresh would force it to be re-argued.

Two things followed that a redraw would otherwise have had to settle. The failure bar's *Try Again*
stays, because it and the pull turned out to scope apart rather than duplicate: the bar re-asks for
the files the Mac refused and the pull asks whether the change set is still the change set. And
nothing new is drawn, so no baseline moves — the gesture is stock and the scroll's own indicator is
the whole report, with the toolbar spinner still reserved for the read nobody asked for.

**The lesson that generalises.** A rejection recorded as a subordinate clause of an argument about a
*different* control is the weakest kind of entry this document holds, and it is worth re-deriving
before it is treated as settled. Every other call in `design.md` names the alternative it beat; this
one named no alternative because it was never the subject of its own paragraph.

