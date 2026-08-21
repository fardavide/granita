---
name: design
description: Granita's client screens are already designed — the four screens, the controls each one must use, the fields that drop first at 390pt, and the calls that are settled. Points at the design authority and names the rules that are binding rather than advisory.
when_to_use: >
  Consult BEFORE writing or changing any SwiftUI in a Client Ui or Presentation target — a screen, a
  row, an empty state, a sheet, a toolbar, a colour or a truncation. Also when choosing a control,
  when a design question feels open, when adding a snapshot state, and when the user asks how
  something should look.
---

# Design

**The client is designed. Do not invent a screen.** The authority is
[`../../docs/design.md`](../../docs/design.md), and the drawings are
[`../../docs/design/granita-design-review.html`](../../docs/design/granita-design-review.html).

This skill is the **answers**. [`design-handoff`](../design-handoff/SKILL.md) is the **round trip** —
when a screen needs a design, what the prompt carries, and the rule that no pull request touching a
screen opens before its frames exist. Reach for that one when a surface has *no* answer yet; reach
for this one when it has.

Read the relevant section of `design.md` **before** the first line of SwiftUI, not after. Every call
in it carries the alternative it beat, so a change that re-opens one is re-litigating something
settled — say so and stop rather than quietly picking the other option.

## The rule that fires most often

**A design question is not an open question.** Four screens are drawn: server discovery (built), the
worktree sidebar, the file selector, the continuous diff. If you are about to choose a control, a
truncation mode, an empty-state action or a colour, the answer is already written down. Look it up.

Only two things are genuinely open, both in §4 and both needing a device rather than another
drawing: the code point size, and whether wrap-off survives on the phone. Everything else has an
answer.

## Binding rules, in the order they get broken

- **Truncation is directional, and the direction is per-screen.** Bonjour device names truncate in
  the **middle** — they differ at the end. Generated worktree directory names truncate at the
  **tail** — the mnemonic is at the front. Paths truncate at the **head** — the filename is what
  identifies them. Never apply one screen's answer to another; the review derives each from what the
  string is.
- **The description slot of an empty state is ours.** Never hand it a framework's localised
  description. A system error string goes to the bottom at caption2, monospaced, tertiary and
  selectable, with its raw code appended.
- **An empty state gets an action only when the reader can act.** Discovery's nothing-found and
  failed states get one; "no projects enabled" deliberately gets none, because there is nothing on
  the phone to tap.
- **Theme the system control.** Every control in the review is a stock one. A hand-rolled equivalent
  loses dark mode, Dynamic Type and platform drift — see the `swift-style` skill.
- **Motion is the progress indicator, and its absence is the result.** No spinner where the protocol
  has no finish; a symbol effect that stops is what says searching stopped.
- **The iPad is the phone at rest in a bigger room.** Pre-pairing screens clamp to a 420pt centred
  measure, title included. Post-pairing, the sidebar is 320pt — *narrower* than the phone — so it is
  the harder layout for a row, not the easier one.
- **Modified is the default case and gets no colour.** Four rows in five are modified; colouring it
  spends the palette on the field carrying no information.
- **Viewed is tapped, never inferred.** The only concession is an explicit "mark everything above".

## When the review's prose and its drawings disagree

It has happened twice already, both in §1, and both are resolved in `design.md` now. The lesson
generalises: **the drawings are measured and the prose is written from them**, so when they conflict,
work out which one the surrounding argument supports — and then **ask Davide** rather than picking.
Both conflicts were a modifier that does not do what the sentence around it assumed.

## When the design and `SPEC.md` disagree

The review contradicts the specification in exactly one place — the rename sheet **offers** the
session suggestion rather than prefilling it. That departure is recorded in
[`../../docs/decisions.md`](../../docs/decisions.md), like every other.

If you find a second disagreement, **stop and ask Davide**; do not resolve it by picking the one you
read most recently. Whichever wins, the answer becomes a `decisions.md` entry in the same pull
request.

## Changing the design

Where a returned call *goes* is `design-handoff`'s table, and it is not repeated here. What this
skill adds is what to do when the design is already written and the code cannot honour it:

1. If a drawing cannot be built as drawn, say what you measured and what it cost — the review is
   full of measurements precisely so a later one can contradict it.
2. Record the new call in `design.md` **with the alternative it replaces**.
3. Re-record the baselines (`swift-testing` skill) so the committed frames and the document agree.
   A baseline that moves while `design.md` does not is the screen drifting, not the design.

**The frames are working material and they expire.** `.claude/docs/design/` holds drawings for
screens that are **not built yet**, and a section's frames are **deleted in the pull request that
implements it** — the built screen is pinned from then on by its snapshot baselines, and a drawing
kept beside them is a second answer to a question that now has a real one. §1's frames are already
gone that way. Do not edit what remains; build it, then remove it.

The prose in `design.md` does **not** expire. It keeps every call and the alternative it beat, which
is what stops a settled question being re-opened once the drawing is gone.

## Sections and where they land

| Section | Screen | Milestone |
|---|---|---|
| §1 | Server discovery | built — the code matches the document |
| §2 | The worktree sidebar | M4 |
| §3 | The file selector | M5 |
| §4 | The continuous diff | M5 |

One §1 call is deferred rather than done: the *Recent* / *Other Macs* sections need pairing history,
which arrives in M4. Until then discovery renders the single unlabelled section the design says it
degrades to — that is the design being followed, not skipped.
