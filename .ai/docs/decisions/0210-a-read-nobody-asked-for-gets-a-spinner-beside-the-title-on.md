# A read nobody asked for gets a spinner beside the title, on a threshold

Both screens that read from a Mac re-read from their own `.task`, so returning to either one fetches
again while the previous answer stays on screen. That is the right behaviour and it was completely
silent: design §8 covers the pull and the *Try Again*, and neither is this. On 15 September 2026
Davide asked for a small spinner beside the device name or the worktree name, and ruled on the two
questions it opened: the gestures keep the feedback §8 gave them, and the automatic read gets the
title instead of a row above the list, "way less invasive … instead of seeing the rows being pulled
down to give space to the spinner". The durable copy and the rejected placements are in
[design §8](../design.md).

**Beside the title means the principal toolbar item, not the leading one.** The first build put it at
`.navigation`, which is the back button's side — the far end of the bar from the name it is about.
Reaching the title slot means drawing the title there; `.navigationTitle` stays anyway, because the
split view takes the sidebar column's header from it and a pushed screen takes its back-button label
from it, and neither reads a principal item.

### The threshold is what makes the indicator worth having

Half a second before it appears. These reads mostly answer inside that on a LAN, so announcing every
one puts a spinner in the bar and takes it out again each time the reader presses Back. It is also
what keeps every resting screen resting: the README's published screenshots are rendered against a
Mac that answers instantly, and the first build without a threshold baked a permanent spinner into
all of them — an app advertised as perpetually loading. The value is shared by both features from the
connection unit's `Domain`, because a constant spelled twice is two answers waiting to disagree.

### A toolbar item that comes and goes takes the whole navigation bar with it

**The defect that cost the most here, and no unit test could see it.** While the spinner was a
`ToolbarItem` that existed only during a refresh, three screen suites rendered a navigation bar with
*nothing* in it — no spinner, no title, no Arrange button — because the bar was being rebuilt as it
was laid out. Losing the Mac's name is a worse defect than the silence the indicator exists to end,
and the reader's only answer to *which machine am I reading* is that title.

The `Ui` suite stayed green throughout, which is the tell: it renders the view with a constant flag
and never changes one mid-render. Only the screens run a `.task` that flips it. Folding the item into
one `.toolbar` modifier did not fix it and neither did making the item's *contents* conditional; what
fixed it was the principal item, which is always present because the title is. **A toolbar item whose
presence is driven by live model state is the shape to avoid** — vary what is inside a permanent
item instead.

