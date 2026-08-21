---
name: design-handoff
description: How Granita asks Claude Design for a screen and takes the answer back — the round trip, what the prompt must carry, why the screens sent are the committed snapshot baselines, why no design system is uploaded, and where a returned call ends up.
when_to_use: >
  Consult before building or redrawing anything a reader looks at — a phone screen, a state a reader
  can land in, the Mac settings window — and whenever Davide says "hand this to Design", "ask
  Design", or asks for a design review. Also when a design comes back and has to be recorded.
---

# Design handoff

## It is a round trip, not a hand-off

A hand-off ends a session: you write the prompt and stop. A design round trip does not. The session
that asks **waits for the answer and then builds it**, so the prompt is written in the middle of the
work rather than at the end of it, and the reply to Davide is the prompt in a fenced code block,
ready to paste, and nothing else after it.

That asymmetry is the whole shape:

| | Who acts next | Where the session ends |
|---|---|---|
| Session → Davide, for something only he can do | Davide | the session is over |
| Session → Claude Design | Design answers, then this session builds | the session continues |

Claude Design does not write code and does not read this repository. It returns frames and an
argument. Turning either into Swift is this session's job, and so is being faithful to it.

## What needs a design, and what does not

The test is one question: **is there a design this code could be wrong about?**

| Needs one | Does not |
|---|---|
| A screen a reader uses, and every state they can land in — empty, error, refused, loading | The CLI's output, the connection log's wording, anything with no reader but a developer |
| A list row: what it says, in what order, and what it does when the strings are long | A copy fix inside a shape that is already settled |
| Two readings that collide in one row, and which one wins | Something the platform decides — a `.sheet` detent's animation, a swipe action's gesture |
| A component that composes several others, or replaces a system one | A layout the spec already fixes to the pixel, where the only question is whether it was built right |

The rule is not "is it big". A five-word empty state is a design; a whole settings tab of stock
form rows, specified control by control in `SPEC.md` §9, mostly is not.

**Do not ship a reader-facing screen with no design behind it.** If one is genuinely needed before
Design can answer, say so in the pull request rather than quietly deciding it at the keyboard.

## The design language is Apple's, and that constrains the ask

Granita has **no design-system module** and does not grow one for v1. There is no token file to
lift into a Claude Design project the way a themed app would: the palette is semantic system
colours with a colourblind-safe alternative, the icons are SF Symbols, and the controls are `List`,
`ContentUnavailableView`, `NavigationSplitView`, `MenuBarExtra` and the standard form rows. The
`swift-style` skill already forbids a hardcoded colour and a hand-rolled control; this is the same
rule seen from the other end.

So **nothing is uploaded to Claude Design** — no bundle, no `DesignSync` push, no component
library. What the prompt does instead is name the idiom and name the system components already on
screen, in as many words. Two things follow, and both belong in the prompt:

- Ask for **decisions inside the idiom** — hierarchy, what a row says and in what order, what an
  empty state offers, which of two readings wins when they collide, what a screen does when the
  data is absurd. Not for a look.
- Say that a returned frame which invents a visual language will be built as the nearest system
  control instead, and that saying *"replace that control with this one, for this reason"* is a
  better answer than drawing a new one. That is a real design call and it is cheap to build.

## The screens sent are the committed snapshot baselines

They live in `Apps/GranitaMobileSnapshotTests/__Snapshots__/<source file name>/`, four renderings
per state — iPhone and iPad, light and dark. Attach them **unrenamed**: the filename ends in
`<state>-<device>-<appearance>`, which is the caption Design needs, and keeping it links every
image back to the test that produced it.

- **Send all four layouts of a state**, not one. A layout defect and a colour defect look identical
  in a single image, which is the same reason the suite renders four.
- **Never redraw a screen by hand to send it.** A hand-made mock is an unchecked claim about what
  the app looks like, and it will be a flattering one.
- **A surface with no baseline gets prose, and the prompt says so plainly** — the Mac settings
  window has no snapshot suite at all, so what goes over is the spec section and the constraint
  list, and what comes back is a first drawing rather than a review. Do not let the two kinds of
  ask blur together inside one prompt; number them separately and label which is which.

## What a prompt carries

Eight parts, in this order. A prompt missing part 3, 5 or 8 gets an answer that has to be thrown
away.

| | Part | The failure it prevents |
|---|---|---|
| 1 | What Granita is, in the one sentence — read the code an agent wrote, from the phone | A reviewer optimising for a git client, which this is not |
| 2 | Where it actually is: the version, what is built, what is a stub, what is only specified | A review of screens that do not exist, written as though they do |
| 3 | The problem **in Davide's own words**, quoted and dated | A paraphrase that has already decided the answer |
| 4 | The surface, one numbered section per screen, each listing the states it must cover | A happy path drawn beautifully and four states missing |
| 5 | Constraints that are not negotiable, with the measurement or the `SPEC.md` TRAP that makes each one real | A frame that cannot be built, and an argument about it |
| 6 | The open calls that could change what is drawn, named as open | A drawing that silently picks one and buries the choice |
| 7 | What is **not** being asked for — v2 is `SPEC.md` §11 and it is explicit | Comments, history browsing, and a week designing v2 |
| 8 | What to send back: name the call, give the recommendation, argue what was rejected and why, and say what it should **feel** like | Frames with no argument, which cannot be reviewed and cannot be overruled |

Part 5 is where this project is unusual, so spend the words: `SPEC.md`'s TRAP paragraphs are
defects found by running things, and several of them constrain a drawing directly — the continuous
scroll may never reflow above the viewport, a `MenuBarExtra` label renders only `Text` and `Image`,
wrap arithmetic is exact only under character wrapping. Quote them rather than summarising them.

A prompt is **a spec plus context, not a leash.** Where a premise of ours does not survive contact
with a real screen, the answer should say so — that is most of what the round trip buys, and the
prompt should ask for it out loud.

## Prompts are committed, dated, and not edited afterwards

One file per round trip at `.claude/prompts/<slice>.md`, opening with what it is for, who wrote it
and when, and against which doc. It is committed **before** the answer arrives, and once the answer
has arrived it is left alone: it is the record of what was asked, and a prompt quietly improved
after the fact makes the answer unreadable.

## What comes back, and where it goes

Three destinations, and the second is the one that matters.

| What | Where | Why |
|---|---|---|
| The frames, as returned | `.claude/docs/design/`, with a row in that README | So a drawing can be looked at rather than remembered |
| The calls, in this repository's own voice | A design sheet under `.claude/docs/`, and `status.md` when a slice moves | Prose survives a re-render; a frame is a snapshot of one moment's answer |
| Anything expensive to reverse | `decisions.md`, newest last, naming what it beat | The standing rule for every decision here |

**A return is a recommendation, not a decision.** Design decisions are Davide's — the same rule as
every other call in this project. Where a frame and a locked item in `SPEC.md` disagree, the spec
wins until Davide says otherwise, and the disagreement is worth one line in the sheet rather than
being silently resolved.

## The session owns fidelity, and the baseline is what pins it

A screen built from a frame **lands with its snapshot baselines in the same pull request**. That is
not a testing preference here: it is the only artefact that can be compared against what Design
returned, and without it "we built the design" is an assertion nobody can check six weeks later.
Cover every state the frame covers, in all four layouts, per the `swift-testing` skill.
