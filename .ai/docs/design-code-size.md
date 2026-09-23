# The code's size — the calls

Calls 10 and 11 of the side-by-side design return of 22 September 2026, which
[`design-side-by-side.md`](design-side-by-side.md) records as **out of scope there** and filed as
[#106](https://github.com/fardavide/granita/issues/106). Built for 0.19.0 against 0.18.0.

**The frames were never archived and the issue body is the record.** The return was drawn in the
Claude Design project at `https://claude.ai/design/p/7a8bd161-884b-4993-9c88-0b09f1cd625e`, and
[`design/README.md`](design/README.md) keeps drawings only while they wait on an implementation —
this pair waited on an issue instead, and the calls travelled as prose. So what is authoritative for
this screen is the issue and this document, and there is no drawing to compare a baseline against.

## `SPEC.md` §10 claimed this existed and it did not

> Code font size adjustable in settings, independent of Dynamic Type, which still governs all
> surrounding chrome.

At 0.18.0 it was two constants in `DiffPaneLayout` — 11pt, and 12 beside the selector — and nothing
read a preference. This is the first release in which that sentence is true, and the sentence is now
half wrong in the other direction: see *Follow system* below.

## Two settings, because they are two questions

**Unified is about legibility and split is about width.** How small a reader will go in the scroll is
a question about their eyes, and 49 characters either way makes it nearly free; how large they will
go in a block is a question about columns, where every point costs about two characters a side from a
number that starts at 22. One setting makes the reader pay for one in the other.

> Rejected: one size. Rejected: a "smaller in split" offset — a third number to hold in your head,
> and wrong the moment a reader wants split *larger*, which on a Mac is the likely case.

**Only one of the two is on screen at a time.** The split's size governs the whole scroll while the
mode is on, not the block rows alone: a block drawn at one size beside the context above it drawn at
another is two text sizes in one file. So *Side by Side* is what chooses between the reader's two
numbers, and flipping it re-lexes every visible file exactly as a theme change already does.

## The readout is in characters

Points are what you set; characters are what you get, and nobody should be asked to predict a
monospaced grid from a point size. Each group says what its size produces at the width the diff is
read at on this device.

> Rejected: a numeric stepper with no readout. Rejected: quoting both devices' numbers, which is
> arithmetic about a screen that is not here.

**The numbers, at 390pt with a three-figure column**, and they are asserted rather than described:

| Size | Unified | Split, a side |
|---|---|---|
| 9 pt | 61 | 28 |
| 10 pt | 54 | 24 |
| 11 pt *(Follow system at Large)* | 49 | 22 |
| 12 pt | 45 | **20 — the floor** |

**Three figures rather than the file's own.** A column is sized from the file it belongs to, so a
thousand-line file pays a fourth figure and loses a character. The screen cannot state a number per
file; `DiffFileLines` remains the authority on what is actually drawn, and this is what is quoted.

## Follow system reverses a rule, deliberately

**One point per Dynamic Type step from Large, clamped to 8–17pt.** Large lands on exactly today's 11
and 12, so nobody's code moves on the update.

That reverses `DiffLineHeight`'s standing rule that the code does *not* scale with Dynamic Type —
which left a reader who had enlarged every other word on the phone reading eleven-point code. It also
makes `SPEC.md` §10's *"independent of Dynamic Type"* true only of the *Custom* half, which is the
half that sentence was really about.

## Follow system clamps the split, and the floor does not bend

**Davide's call, 23 September 2026.** Twelve points is exactly twenty characters a side at 390pt, so
every Dynamic Type size above Large would otherwise put a *Follow system* reader below the split's
own floor — an accessibility setting silently removing a feature.

**The split's *Follow system* never passes the largest size that still fits two columns at this
device's width, and the group says so.** What it costs is real and stated: on a reader at a large
system text size, the code inside a block is smaller than the code around it.

> Rejected: **bending the floor**, which reverses design §4.2's call 7 — the floor is in characters
> precisely so it is one rule at every width, and an eleven-character cell is not a diff viewer.
> Rejected: **honouring the size and disabling the layout**, which on a phone leaves no gesture that
> brings it back.

**The ceiling is this width's, not a constant twelve.** On an iPad's pane or a wide Mac window
seventeen points still leaves thirty-five characters a side, so nothing clamps there — a reader on a
big screen handed the phone's answer would be the setting being wrong rather than cautious.

**A *Custom* size is never held back.** Capping the stepper was rejected as a ceiling that moves
while a Mac window is dragged, and as a setting that silently means something different on each
device. The reader gets the number they set, and the control says what it costs.

## The disabled toolbar item names the cause that applies

**Two sentences, chosen by which constraint is binding**, and this is the second of Davide's two
calls of 23 September 2026:

| Bound by | The item says |
|---|---|
| The room | *Widen the window to review side by side* |
| The size | *Choose a smaller code size to review side by side* |

The width is asked first: a row too narrow to hold two columns at 8pt cannot be fixed by choosing a
size, so it is the width's row to answer.

> Rejected: one sentence naming both levers, which on a phone is half advice the reader cannot take.

**That state did not exist at `main`, and building it is this slice's.** Design §4.2 asked for it and
§57 shipped without it: below the floor the blocks closed, the toolbar item stayed live, and nothing
said why. It was unreachable on a phone until this setting existed, which is what turned a latent
gap into one a reader could land in.

**Where the sentence is visible is not settled by the toolbar.** A disabled toolbar item can carry a
tooltip on a Mac and a VoiceOver hint anywhere; a sighted phone reader sees a dimmed glyph and
nothing else. So the same sentence is in the *Code size* screen's split group, which is also the only
place the reader can act on it. That is a departure from the design's own wording and is recorded in
[`decisions.md`](decisions.md).

## The screen: a push from the appearance section

**A third row in `APPEARANCE`**, below *Code colours*: *Code size*, its value, a chevron. The value
is the **unified** size, because that is the scroll a reader spends nearly all their time in — the
split's own number is one push away and only ever differs when they have made it so.

**A third row rather than a second section**, which keeps the footer saying the device divide once.
That sentence now reads *"None of them changes what a review says"* rather than *"Neither"*.

The pushed screen is two `Form` sections:

| Group | Control | Under it |
|---|---|---|
| *Unified scroll* | Follow system / Custom, segmented | A stepper, 8–17pt, only under *Custom* |
| *Side by side* | Follow system / Custom, segmented | The same |

**The stepper is absent under *Follow system* rather than disabled**, which is the first of this
project's permitted answers: a stepper the reader can read a figure in but not move is a control
asking a question the segment above it has already answered.

**Switching to *Custom* opens the stepper at the size already on screen**, including when that size is
the held-back one. A stepper that opened at eleven for a reader whose text size had them at fifteen
would move their code the moment they touched the control that is about not moving it.

**The split group's footer carries up to three sentences**: the count always, the hold when there is
one, and the refusal when there is one. Both extra sentences are absent rather than reworded when
they do not apply.

## Device-local, with the appearance and the colours

No `StoreDocument` field, no wire, no schema and no compatibility answer for an older Mac. It is the
sharper version of the argument the other three device-local settings make: a size is how one screen
is read, and the 390pt it is being read at is not a fact any other device shares.

**Stored as one optional figure per half.** An absent key is *Follow system*, which is what lets the
two segments live in one value with no second key saying which is on — and `bool(forKey:)`'s trick
does not transfer, because 0 is a point size somebody could believe in. Going back to *Follow system*
**removes** the key rather than writing a sentinel, or the next read would find the number and turn
the segment back.

## Two widths, and which one governs what

**The diff screen measures its own pane; the settings sheet derives one from the window.** A sheet
cannot see the pane it is describing, so `AppearanceRoot` — the one view that is the whole window —
measures the window and takes the tree's width off it wherever a tree could stand.

They agree exactly on the phone and to within a divider beside a selector column. **The measured one
governs every decision and the derived one only ever states a number**, so a point of disagreement
costs a character in a sentence and never a press.

**The tree's width comes off wherever a tree could fit, open or shut** — `DiffPaneLayout`'s own rule:
a size taken from the folded width would change every time the fold did, and re-lex the file the
reader is halfway down.

## What this leaves for a later round

- **`SPEC.md` §10's sentence is now half true and should be rewritten**, not deleted: *Custom* is
  independent of Dynamic Type and *Follow system* is deliberately not.
- **A thousand-line file can refuse a split the toolbar item says is available.** The item is
  answered at three figures and the file is drawn at four, which costs one character — reachable at
  12pt on a 390pt phone and nowhere else this product has been measured. Whether the item should be
  answered per visible file is a question for a device rather than for a document.
- **Nothing measures the re-lex.** Changing either size re-lexes every visible file, which is the
  pass a theme change already costs and which [`verification.md`](verification.md) still records as
  unmeasured on a device. This setting makes it deliberate and repeatable rather than twice a day.
