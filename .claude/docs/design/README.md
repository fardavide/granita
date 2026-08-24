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
| [`granita-design-review.html`](granita-design-review.html) | The file selector and the continuous diff (M5). 21 August 2026, drawn against 0.0.4 | [`../design.md`](../design.md) |

Server discovery was in that file too, and was implemented in 0.0.6; its frames went with it. The
worktree sidebar followed in 0.0.19 — and its frames left with **two of their strings recorded in
[`../decisions.md`](../decisions.md) rather than built**, because they contradicted a rule stated in
the prose beside them. That is the case this rule exists for: the drawing was one moment's answer,
and what survives it is the argument.

**The Mac's review is gone, which is this rule working rather than a loss.** All seven of its
surfaces are built — General in 0.0.10, Connections in 0.0.11, Advanced in 0.0.11, Projects in
0.0.14, Devices in 0.0.15, and the status item and the window in 0.0.16 — so the last frames were
deleted with the last section. [`../design-mac.md`](../design-mac.md) is the whole record now: every
call beside the alternative it beat, both open calls answered, and each measurement the frames were
carrying. The one Mac surface still without a drawing has never had one — allowing a device from the
Mac, which is [waiting on Davide](../status.md).

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
