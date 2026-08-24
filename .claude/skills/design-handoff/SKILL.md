---
name: design-handoff
description: How Granita asks Claude Design for a screen and takes the answer back — that no pull request touching a screen opens before the frames exist, the round trip, the eight parts a prompt must carry, why the screens sent are the committed snapshot baselines, why no design system is uploaded, and where a returned call ends up.
when_to_use: >
  Consult before building or redrawing anything a reader looks at — a phone screen, a state a reader
  can land in, the Mac settings window — and BEFORE opening any pull request that touches one, since
  that is the thing this skill forbids while a design is outstanding. Also whenever Davide says
  "hand this to Design", "ask Design", or asks for a design review, and when a design comes back and
  has to be recorded.
---

# Design handoff

It is a **round trip, not a hand-off**: the prompt is written in the middle of the work, and the
screen comes back here to be built. The reply to Davide is the prompt in a fenced code block, ready
to paste, and nothing else after it.

The reasoning behind every rule below — the quotes, the failure each one prevents, and why the
design language constrains the ask — is in [why-the-round-trip.md](references/why-the-round-trip.md).

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

## No pull request for a screen until its design has come back

**A branch that touches a reader-facing screen does not become a pull request before the frames
exist.** Not as a draft, not as "the structure, styling to follow", not as a scaffold with a to-do
in it.

The order is fixed:

1. Prompt, in the reply, in a code block.
2. Wait. The session does something else, or it ends.
3. Frames come back and are recorded.
4. **Then** the branch, the screen, its baselines, and the pull request.

**Nothing about the screen is built while the wait is on.** Work a frame cannot be authoritative
about — a view model, a repository, a mapper, a domain type, a test — is ordinary work and ships
normally; pushing logic down so the view layer is thin is the right move, not a workaround.

If a screen is genuinely blocked on a design that has not been asked for yet, **the answer is to
write the prompt, not to open the pull request and flag it.** Say plainly that the work is waiting.

## The design language is Apple's, and that constrains the ask

Granita has **no design-system module** and does not grow one for v1, so **nothing is uploaded** — no
bundle, no `DesignSync` push, no component library. The prompt names the idiom and names the system
components already on screen, in as many words. Two things follow, and both belong in the prompt:

- Ask for **decisions inside the idiom** — hierarchy, what a row says and in what order, what an
  empty state offers, which of two readings wins when they collide, what a screen does when the
  data is absurd. Not for a look.
- Say that a returned frame which invents a visual language will be built as the nearest system
  control instead, and that saying *"replace that control with this one, for this reason"* is a
  better answer than drawing a new one. That is a real design call and it is cheap to build.

## The screens sent are the committed snapshot baselines

Copy them to the Desktop for sending, stripping the long test-name prefix and keeping the
`<state>-<device>-<appearance>` tail — that tail is the caption Design needs.

- **Send all four layouts of a state**, not one.
- **Never redraw a screen by hand to send it.**
- **A surface with no baseline gets prose, and the prompt says so plainly** — the Mac settings
  window has no snapshot suite at all, so what goes over is the spec section and the constraint
  list, and what comes back is a first drawing rather than a review. Do not let the two kinds of
  ask blur together inside one prompt; number them separately and label which is which.

## What a prompt carries

Eight parts, in this order. **A prompt missing part 3, 5 or 8 gets an answer that has to be thrown
away.**

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

Spend the words on part 5 — quote the TRAP paragraphs rather than summarising them. A prompt is a
spec plus context, not a leash.

## The prompt is chat output, and the images go on the Desktop

**Do not write the prompt to a file and do not open a pull request for it.** The reply ends with the
prompt in one fenced code block, and nothing after it. Copy the baselines it references into a
folder on the Desktop, named for the round trip, and say in the reply how many there are and where
they are.

## What comes back, and where it goes

Three destinations, and **the second is the one that matters**.

| What | Where | Why |
|---|---|---|
| The frames, as returned | `.claude/docs/design/`, with a row in that README | So a drawing can be looked at rather than remembered |
| The calls, in this repository's own voice | A design sheet under `.claude/docs/`, and `status.md` when a slice moves | Prose survives a re-render; a frame is a snapshot of one moment's answer |
| Anything expensive to reverse | `decisions.md`, newest last, naming what it beat | The standing rule for every decision here |

**A return is a recommendation, not a decision.** Where a frame and a locked item in `SPEC.md`
disagree, the spec wins until Davide says otherwise, and the disagreement is worth one line in the
sheet rather than being silently resolved.

## The session owns fidelity, and the baseline is what pins it

A screen built from a frame **lands with its snapshot baselines in the same pull request**. Cover
every state the frame covers, in all four layouts, per the `swift-testing` skill.
