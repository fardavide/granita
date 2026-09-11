# Why the round trip works the way it does

Evidence and reasoning behind the rules in the `design-handoff` skill.

## Contents

- Why it is a round trip and not a hand-off
- Why a pull request may not open first — and what it does not forbid
- Why nothing is uploaded to Claude Design
- Why part 5 of the prompt is where this project is unusual
- Why the prompt is chat output and never a file
- Why the images sent are baselines rather than mocks
- Why a frame does not settle a call
- Why the baseline is what pins fidelity

## Why it is a round trip and not a hand-off

A hand-off ends the work: you write the prompt and the thing you were building is somebody else's
now. A design round trip does not. The screen is still this work's to build — the prompt is written
in the **middle** of it, and what happens next is waiting, not handing over.

| | Who acts next | What happens to the work |
|---|---|---|
| → Davide, for something only he can do | Davide | it is his now |
| → Claude Design | Design answers | it comes back here, unstarted, and is built then |

Waiting can outlast a session, and that is fine — the point is that **nothing about the screen is
built while the wait is on**, not that one conversation stays open.

Claude Design does not write code and does not read this repository. It returns frames and an
argument. Turning either into Swift is this side's job, and so is being faithful to it.

## Why a pull request may not open first

Davide, **2026-08-21**, on Oltre having done exactly this: *"opened a PR while not having designs
yet: this should never happen."*

A pull request is the point at which a decision stops being provisional. Layout, hierarchy, which
control, what a row drops first — those get decided the moment the code is written, and a PR asks
Davide to review them as though they were considered.

He then has two bad options: approve a design nobody designed, or block a green branch on a round
trip that had not been started. The frames arriving afterwards do not fix it either, because now
they are being fitted to code rather than the other way round.

### What this does not forbid

Work that a frame cannot be authoritative about — a view model, a repository, a mapper, a domain
type, a test — is ordinary work and goes through ordinary pull requests whenever it is ready.
Pushing the logic down so the view layer is thin is the **right move** while a design is
outstanding, not a workaround.

A screen with genuinely nothing to design about it, judged by the "what needs a design" table, does
not need a round trip at all.

## Why nothing is uploaded to Claude Design

Granita has **no design-system module** and does not grow one for v1. There is no token file to lift
into a Claude Design project the way a themed app would: the palette is semantic system colours with
a colourblind-safe alternative, the icons are SF Symbols, and the controls are `List`,
`ContentUnavailableView`, `NavigationSplitView`, `MenuBarExtra` and the standard form rows.

The `swift-style` skill already forbids a hardcoded colour and a hand-rolled control; this is the
same rule seen from the other end.

So no bundle, no `DesignSync` push, no component library. What the prompt does instead is name the
idiom and name the system components already on screen, in as many words.

## Why part 5 of the prompt is where this project is unusual

`SPEC.md`'s TRAP paragraphs are defects found by running things, and several of them constrain a
drawing directly:

- the continuous scroll may never reflow above the viewport
- a `MenuBarExtra` label renders only `Text` and `Image`
- wrap arithmetic is exact only under character wrapping

Quote them rather than summarising them.

A prompt is **a spec plus context, not a leash.** Where a premise of ours does not survive contact
with a real screen, the answer should say so — that is most of what the round trip buys, and the
prompt should ask for it out loud.

## Why the prompt is chat output and never a file

Davide, **2026-08-21**: *"You give prompt in chat in code block, not in files. If we need to attach
image, you place them on desktop."*

A prompt is something he pastes once, in the next thirty seconds, into another tool — committing it
puts a review gate in front of a clipboard. What is worth keeping in the repository is the
**answer**, not the ask.

## Why the images sent are baselines rather than mocks

A hand-made mock is an unchecked claim about what the app looks like, and it will be a flattering
one.

Send **all four layouts of a state**, not one: a layout defect and a colour defect look identical in
a single image, which is the same reason the suite renders four.

The baselines live in `Apps/GranitaMobileSnapshotTests/__Snapshots__/<source file name>/`, four
renderings per state — iPhone and iPad, light and dark. The filename ends in
`<state>-<device>-<appearance>`, which is exactly the caption Design needs, so keep that tail and
drop only the long test-name prefix in front of it. A folder of files that all begin with the same
sixty characters cannot be read at a glance.

## Why a frame does not settle a call

Design decisions are Davide's — the same rule as every other call in this project. Where a frame and
a locked item in `SPEC.md` disagree, the spec wins until Davide says otherwise, and the disagreement
is worth one line in the sheet rather than being silently resolved.

## Why the baseline is what pins fidelity

That a screen lands with its baselines is **not a testing preference here**: a snapshot baseline is
the only artefact that can be compared against what Design returned. Without it, "we built the
design" is an assertion nobody can check six weeks later.
