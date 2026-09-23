# Side by side — the calls

Returned 22 September 2026 for issue [#57](https://github.com/fardavide/granita/issues/57), drawn
against 0.17.0. The original is in the Claude Design project at
`https://claude.ai/design/p/7a8bd161-884b-4993-9c88-0b09f1cd625e` under
`Granita Side by Side Design Review.dc.html` if it is ever wanted again; it is not archived under
[`design/`](design/), because that directory is for drawings waiting on an implementation and this
one was built in the same slice.

The one sentence the whole return rests on is Davide's: *"some blocks of code are easier to review
side by side, especially when there is an indentation change."*

## The unit is the paired run, not the file

**A maximal run of deletions immediately followed by additions opens into two columns. Nothing else
does.** Context, a change with only one side, a conflict marker and git's no-newline annotation are
the rows they are today, on one grid, at the width they have now.

That is the call every other one below follows from, and it is the one most likely to be overruled —
for reasons of expectation rather than evidence, because everyone has seen GitHub's two columns and
this is not them.

> Rejected: **the whole file in two columns.** Four rows in five of an ordinary change set are
> context, and context is the same string drawn twice — so that form halves the width of every row
> in the file in order to align the rows that are identical, and it makes the reader *check* that
> they are identical, which is work the unified scroll never asks for. At 390pt it takes an ordinary
> line from 49 characters to 22. It is also the form that cannot survive the phone: the most
> aggressive case available — both figure columns and both markers dropped — reaches 28 characters,
> and that is a layout that has thrown away the line numbers a comment is anchored to.
>
> Rejected: **a pager between the two sides, and a hold-to-swap.** Both put the two sides in the same
> pixels one at a time, which is the unified scroll's own fault with a gesture added. The
> hold-to-swap works for a changed image because the two frames are the same size and the same
> subject; two runs of code are neither, and the thing that moved is what you are trying to see. A
> horizontal pager also spends the one axis the diff already owns.

**The run is recovered from the line kinds rather than from the word-diff segments.** A run the word
differ refused to pair — too different, or a line past its thousand-character limit — still has two
sides, and a re-indented long line is exactly that case.

## An unbalanced run's tail faces nothing, drawn as nothing

A run of five deletions against two additions is five rows, three of them with an empty new cell.
The cell carries no tint, no figure, no hatch and no rule of its own: the card shows through, and the
block's vertical rule is what says the block continues past it.

> Rejected: a tint, which would claim the side has a line there. Rejected: hatching, which is a new
> drawn texture in an app that owns exactly one. Absence reads as absence when everything around it
> is a filled rectangle.

## Figures kept, markers dropped, tints per cell

Each cell carries **its own figure column**. Inside a block every left row is a deletion and every
right row an addition, so the `+`/`−` marker would be 18pt restating the column it is standing in —
it goes. Outside a block it is untouched, so the glyphs never leave the file.

The row tint moves from the row to the **cell**, covering its figures and its code and stopping at
the rule, because in two columns which side a row is on is positional.

> Rejected: one shared figure column, which cannot say which side it numbers on the rows where the
> two differ — and inside a block most rows are exactly that. Rejected: reserving the marker's 18pt
> for alignment with the rows above, which buys a column nobody scans and costs three characters on
> the narrowest row in the app.

The word-diff background is the one treatment that gains importance here: in a 22-character cell it
is the only thing left saying *this part*. It keeps its solved alpha and its pinned 3× ratio.

## The tear does not change

A gap is what the diff skipped, which is context on both sides — and context never splits. All three
forms of the expander keep their drawing, their 44pt, their glyph in the file's own figure column and
their two controls between hunks. `DiffFileRow.rows(of:)` already puts gaps *between* hunks rather
than inside them, so this is structural rather than a decision.

> Rejected: one tear per side. It would have to be drawn per column to mean anything, and there is no
> state in which the two columns have skipped different regions.

## A toolbar toggle, called Side by Side

One toolbar item on the diff screen: `rectangle.split.2x1`. A toggle rather than a menu, because it
has two states and the reader flips between them while reading a block.

**The glyph is hollow in both states, which the return did not ask for.** §4.5 specifies it filled
when on. Built that way and photographed, the filled pair is two solid slabs — the heaviest thing in
a toolbar whose screen is the code, sharing a capsule with *7 files* so that the two read as one
control, which is the fault `design.md` §2 already names on the iPad bar. Davide, 22 September 2026:
*"the fill state is too heavy… I don't like the icon. It's too simple and doesn't represent
anything."*

The glyph survived the second half of that on a rendered comparison of twelve candidates: hollow, it
is a thin outline rather than a slab, and the alternatives each cost more than they bought —
`sidebar.squares.left` collides with the selector fold's own `sidebar.leading` two items away,
`doc.on.doc` reads as duplicate, `arrow.left.arrow.right` as transfer,
`chevron.left.forwardslash.chevron.right` as merely *code*, and `plus.forwardslash.minus` says
*diff* while saying nothing about two columns. `arrow.left.and.right.text.vertical` was the one that
genuinely depicts text being compared and was rejected as too busy at 20pt.

**What says the mode is on is the platform's selected background**, drawn by `.toggleStyle(.button)`
rather than by a second glyph. One vocabulary the reader already knows from every other toolbar,
instead of a swap they have to learn — and a `Toggle` announces its own on-and-off state, which is a
better accessibility answer than two hand-written labels.

> Rejected: the file header's unbuilt menu, which would make this feature also specify when that menu
> ships. Rejected: a Settings row, which is two navigations from the code and would read as a
> preference rather than a posture. Rejected: a segmented bar under the navigation bar, which is
> permanent chrome on a screen that just bought 17pt back.

## Global, device-local, remembered

One flag beside the appearance and the code theme. No `StoreDocument` field, no wire, no schema and
no compatibility answer for an older Mac: it is how this reader reads, not a fact about the review.

> Rejected: per-file, which is eleven decisions in an eleven-file pass and eleven anchored relayouts.
> Rejected: per-worktree, which makes the reader re-state a posture they have already stated every
> time they open the next worktree.

**On a change set with no paired run in it the toggle changes nothing on screen, and it stays live.**
The return recommended keeping it and offered *absent until a run is loaded* as the overrule. Davide
settled it differently and more simply on 22 September 2026: *"while there is no change, it will not
do anything, but it will save the setting for the future. The setting should be saved globally."* It
is a setting, and a setting's perceivable effect is that it is remembered — which is what keeps it
clear of the dead-control rule rather than an exception to it.

## One floor, stated in characters

**Twenty characters a side.** Below it every block draws unified and the toolbar item goes disabled
carrying *Widen the window to review side by side*, re-enabling on the drag back.

> **This slice did not build the disabled state**, and 0.19.0 did. The blocks closed and the toolbar
> item stayed live, because `SplitBlockLayout.fits` was consulted only inside `DiffFileLines`. It is
> also two sentences now rather than one — *Choose a smaller code size to review side by side* where
> the code size rather than the room crossed the floor, which is a state only
> [#106](https://github.com/fardavide/granita/issues/106)'s own setting made reachable on a phone.
> In [`design-code-size.md`](design-code-size.md).

| Surface | Code columns | Split, a side |
|---|---|---|
| iPhone 390pt, 11pt, three figures | 49 | **22** (21 at four figures) |
| iPad 846pt pane, 12pt | 110 | **51** |
| Mac Client at 760pt | — | 45 |
| The floor | — | **20**, which is 358.6pt of row |

> Rejected: falling back at the iPad's pane width, which would make a 500pt Mac window refuse a
> layout it has the room for. Rejected: a notice in the scroll, which is chrome that appears while
> the reader is reading.

## Wrap-off is the requirement, not the limitation

The split needs one row per line, a constant row height and a pairing the parser already made, and
wrap-off gives all three. **This ships before wrap-on and constrains it**: when wrap-on arrives,
either both cells of a block wrap to the same row count and the shorter is padded, or the two modes
are mutually exclusive. That is a decision wrap-on now inherits.

## Where the build departs from the return

Five, and the first is the only expensive one. All of them are in [`decisions.md`](decisions.md).

- **The toolbar glyph is hollow in both states**, where §4.5 asks for it filled when on, and the
  platform's selected background carries the mode instead. Davide's call on the built screen — the
  section above has the argument and the twelve candidates it was tested against.

- **The cells ride the hunk's scroll offset rather than sharing a scroll with it.** The return asks
  for "one drag moves the context and both cells together" and reaches for the shared hunk scroll to
  get it — but content inside a `ScrollView` travels as one piece, so two cells at fixed screen
  positions cannot both stay put while it slides. What ships reads the offset the hunk's scroll
  already reports and applies it to each cell, which gives the same sentence from the other end: one
  scroll, one gesture, nothing that can desynchronise. Davide's call, 22 September 2026.
- **The anchor is the file, not the line.** Call 9 asks for the top visible `(fileID, lineIndex)` to
  be captured and restored by computing the line's new row index. `scrollPosition(id:)` positions by
  section identity, and the section is a file — so what is preserved across a mode change is the
  file the reader was in, not the line. It also inherits the 120pt short landing already recorded in
  [`status.md`](status.md). **Line-level anchoring is not built.**
- **The floor is 358.6pt, not 358.** Twenty characters of code is 132pt, which with a 32.8pt figure
  column makes a 164.8pt cell and a 358.6pt row; the return rounded it down. The character count is
  truncated rather than rounded, because a cell showing nineteen characters and most of a twentieth
  shows nineteen.
- **A no-newline annotation ends a run rather than being looked past.** `WordDiff` looks past it so
  that a file with no trailing newline still gets its words compared. Two columns cannot: the
  annotation is not a line of the file, so it has no side to be drawn on, and lifting it out of the
  middle of a block would put it somewhere the parser did not. That one run draws unified.

## What the return raised that is not this feature's to answer

- **§10's sticky-height cache does not exist.** The cache keyed on
  `(fileID, contentHash, wrapMode, availableWidth, fontSize)` is prose only; what holds the line is
  `ContinuousDiffEntry.reservedRows` and an append-only loader. Nothing here needed it — a row is
  `DiffLineHeight.at(pointSize:)` tall whatever is in it, and a run of `d` against `a` is `d + a`
  rows unified and `max(d, a)` split, which is arithmetic over the model rather than a measurement.
  Either `SPEC.md` should say so or the cache should be scheduled.
- **§10's "the code size is its own setting" was never true.** It is two constants in
  `DiffPaneLayout`. The return's calls 10 and 11 build that setting for the first time and were
  **out of scope here** — Davide's call, 22 September 2026 — filed as
  [#106](https://github.com/fardavide/granita/issues/106) and built in 0.19.0. The calls are in
  [`design-code-size.md`](design-code-size.md).
- **The 120pt short landing becomes load-bearing** the moment a toggle relies on the same mechanism.
  It was a question for a real thumb; it is now a question for a release.
