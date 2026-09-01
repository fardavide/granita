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
| [`granita-design-review.html`](granita-design-review.html) | The continuous diff's second header form and wrap-on (M5). **Not syntax highlighting** — this row claimed it until 0.4.2 and the file has never held a frame of it: §4 has eight subsections and none is highlighting, and the only two mentions in the whole review are a rejection of underlining that names the highlighter in passing. 21 August 2026, drawn against 0.0.4 | [`../design.md`](../design.md) |
| [`granita-pairing-design-review.html`](granita-pairing-design-review.html) | The already-paired state, which 0.4.1 made reachable and deliberately did not build: a Mac paired with before goes straight to its worktrees, so the only reader who lands here is one whose token the Mac revoked. 25 August 2026, drawn against 0.0.19 | [`../design.md`](../design.md) §5 |

The pairing return arrived with **twelve** states and left with one, because the pull request that
recorded it also built the other eleven. What it carried that no frame could — that the six words
carry no key, and what a screen owes a reader instead — is in §5 and in
[`../decisions.md`](../decisions.md).

Its one illustrative asset, `assets/pair-qr.svg`, was deliberately **not** copied: the only frames
that used it are frames this slice deleted, and the original is in the Claude Design project at
`https://claude.ai/design/p/7a8bd161-884b-4993-9c88-0b09f1cd625e` if it is ever wanted again.

Server discovery was in that file too, and was implemented in 0.0.6; its frames went with it. The
worktree sidebar followed in 0.0.19 — and its frames left with **two of their strings recorded in
[`../decisions.md`](../decisions.md) rather than built**, because they contradicted a rule stated in
the prose beside them. That is the case this rule exists for: the drawing was one moment's answer,
and what survives it is the argument.

The file selector went in 0.3.0, and it left the same way: **two of its calls are recorded rather
than built**, because one of the numbers its frame prints is not on the wire and the other would have
meant rebuilding the one navigation path this repository cannot press. Both are in
[`../decisions.md`](../decisions.md).

The collapsed bars and hunk expansion went in 0.4.0, and left three calls recorded rather than built:
the viewed bar says **"viewed"** and not "viewed 4 minutes ago", because the Mac keeps no time beside
a mark; the two rows with nothing behind them are drawn with **no chevron** rather than the faded one
the frame shows, because a faded chevron is still a chevron; and *Expand all* is absent with the menu
it belongs to, which arrives whole or not at all.

**The diff design review arrived and left in the same release**, which is the shortest this cycle has
ever been: it was a review of a screen already built, so there was nothing to wait for. Davide sent a
photograph of the running app on 1 September 2026 and it came back with eight faults, six rules and
five frames. What it left recorded rather than built is in [`../design.md`](../design.md) §4 — the
inline title it wanted to make large, the change-set totals its own note calls invented, and the
proportion bar it ruled out of its own scope. What it **reversed** is in
[`../decisions.md`](../decisions.md): §4's rejection of a single interleaved gutter column, and §3's
rule that modified gets no colour. Two calls in it were overruled here — the marker column keeps its
44pt hit area by taking it horizontally, and the iPad keeps a 12pt code size rather than the second
gutter column §4 had argued for.

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
