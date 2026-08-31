---
name: design
description: Granita's screens are already designed — the client's four, the Mac's seven, the controls each one must use, the fields that drop first at 390pt, and the calls that are settled. Points at the design authority and names the rules that are binding rather than advisory.
when_to_use: >
  Consult BEFORE writing or changing any SwiftUI in a Client or Server Ui or Presentation target — a
  screen, a Settings tab, a menu, a row, an empty state, a sheet, a toolbar, a colour or a
  truncation. Also when choosing a control, when a design question feels open, when adding a snapshot
  state, and when the user asks how something should look.
---

# Design

**Both halves are designed. Do not invent a screen.** The authorities are
[`../../docs/design.md`](../../docs/design.md) for the phone and the iPad and
[`../../docs/design-mac.md`](../../docs/design-mac.md) for the menu bar app, and the drawings are the
two files in [`../../docs/design/`](../../docs/design/).

**The Mac's frames are one release older than its sheet.** They were drawn against 0.0.6; 0.0.7
repaired two of the five premises they overturn and made a third obsolete. `design-mac.md` records
the corrected calls and marks which still stand — build from the sheet, and use the frames for
measurements. Building the drawing as returned would put a "this link is not encrypted" warning under
a QR that now carries a real pinned key.

This skill is the **answers**. [`design-handoff`](../design-handoff/SKILL.md) is the **round trip** —
when a screen needs a design, what the prompt carries, and the rule that no pull request touching a
screen opens before its frames exist. Reach for that one when a surface has *no* answer yet; reach
for this one when it has.

Read the relevant section of `design.md` **before** the first line of SwiftUI, not after. Every call
in it carries the alternative it beat, so a change that re-opens one is re-litigating something
settled — say so and stop rather than quietly picking the other option.

## The rule that fires most often

**A design question is not an open question.** Eleven surfaces are drawn. On the client: server
discovery (built), the worktree sidebar, the file selector, the continuous diff. On the Mac: the
status item and its menu, the window's five tabs, and each of General, Projects, Devices, Connections
and Advanced. If you are about to choose a control, a truncation mode, an empty-state action or a
colour, the answer is already written down. Look it up.

Four things are genuinely open, and none of them is answered by another drawing:

- The code point size, and whether wrap-off survives on the phone (client §4) — both need a device.
- Whether the menu bar's dirty-worktree count is affordable — needs `WorktreeRegistry.projects()`
  timed on a real machine with real projects enabled.
- What happens when the store's lock file is already held — refuse to start, or serve read-only. A
  question for Davide, not for a designer.

Everything else has an answer.

## Binding rules, in the order they get broken

- **Every control on a screen must do something the reader can perceive — before that screen
  ships.** It ships only if it works, is absent, is disabled **and** says why, or explains that what
  is behind it is not built. A row, button or link that looks operable and silently does nothing is
  the worst thing this product can ship, and it shipped one for eight releases: discovery's rows
  were `NavigationLink`s and no module declared a `navigationDestination` for their value, so
  tapping the Mac you opened the app to read answered with silence. **Being mid-slice is not an
  excuse — it is the case the rule is for**, and Granita's layer graph hides it best, because every
  layer looks finished on its own and the gap was between two modules. When what is behind a control
  is not built, the control says so in our voice, using this design's own empty-state idiom — never
  `TODO`, never "coming soon". **Run the app and press it**: the snapshot suite rendered that dead
  row in four layouts and stayed green throughout, because a baseline photographs a button whether or
  not anything is behind it. Declare a link's destination in the same file as the link. Full account
  in [`../../docs/decisions.md`](../../docs/decisions.md).
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
- **A layout the reader changed moves; it never teleports.** The global `ui-motion` skill owns the
  rule. What is Granita's is that the review's disclosures — a file shutting or opening in §4's
  scroll, a hunk's context expanding, a directory in §3's selector — all move on
  `Animation.disclosure`, keyed on the value that changed. A fifth one reuses it rather than picking
  a curve. **The modifier goes on the container that lays out the movement** — §4's lazy stack, §3's
  list, a file's own column — and never on the row or section inside it: 0.5.2 put §4's on the two
  halves of a file's section, which cross-faded the bar into the header while every file below it
  snapped, and shipped as a fix that fixed one site of three. **Do not confuse any of this with
  `SPEC.md` §10's no-reflow rule**, which forbids content moving *unasked* and has never been an
  argument for a layout that jumps when it is pressed; §10 is why this was missed for four releases.
  Nothing in the snapshot suite can see it — that suite stayed green through every one of those
  releases, and through 0.5.2's half-fix — so it is checked by pressing the control.
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
