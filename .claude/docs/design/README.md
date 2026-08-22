# Design returns, waiting to be built

Frames as Claude Design returned them, so a drawing can be looked at rather than remembered. **The
durable half is not here** — it is the prose in whichever doc records the calls, and that is what to
read first. A frame is one moment's answer to one question; the sheet is what the answer became.

**This directory holds design for screens that are not built yet, and it empties as they are.** It is
working material, not a record. Davide, 2026-08-21: *"We're not saving design as a documentation,
we're saving actual design for the upcoming implementation. Once implemented, they are gone."*

So when a section ships, **delete its frames in the same pull request** — the built screen is pinned
from that moment by its own snapshot baselines, and a drawing kept beside them is a second answer to
a question that now has a real one. When a file's last section ships, the file goes.

| File | Still to build | Read the calls in |
|---|---|---|
| [`granita-design-review.html`](granita-design-review.html) | The worktree sidebar (M4), the file selector and the continuous diff (M5). 21 August 2026, drawn against 0.0.4 | [`../design.md`](../design.md) |
| [`granita-mac-design-review.html`](granita-mac-design-review.html) | Six sections — the status item, the window, and four of the five Settings tabs (M3). 21 August 2026, drawn against 0.0.6. **General went with 0.0.10** | [`../design-mac.md`](../design-mac.md) |

Server discovery was in the first file too, and was implemented in 0.0.6; its frames went with it.

**The Mac frames are one release out of date, and the sheet is not.** They were drawn against 0.0.6
and 0.0.7 landed after, repairing two of the five premises the review overturns and making a third
obsolete. `../design-mac.md` records the calls as corrected and says which still stand — read it
first, and treat the frames as measurements rather than as instructions.

The round trip that produces these, what the prompt has to carry, and where a returned call ends up
are all in the [`design-handoff`](../../skills/design-handoff/SKILL.md) skill.

## What is not archived here

**Anything that is argument rather than drawing.** A decision sheet that comes back as prose gets
carried into this repository's own voice — into a doc under `../`, into `decisions.md` when it is
expensive to reverse — rather than copied. Note in the row above where the original lives if it is
ever worth re-fetching.

**The screens that were sent.** Those are the committed snapshot baselines under
`Apps/GranitaMobileSnapshotTests/__Snapshots__/`, and a second copy would rot the moment a baseline
was re-recorded.
