# Design

The client's eight screens, judged and drawn. This is the authority on **what the phone and the iPad
look like and why**, and it is the half that lasts. The Mac's own surfaces are in
[`design-mac.md`](design-mac.md).

The drawings do not. The two files in [`design/`](design/) are working material for the screens
still to be built — open them for §3 and §4, whose frames carry measurements this prose only
summarises — and each section is **deleted from them as it is implemented**. §1's, §2's and eleven
of §5's twelve frames have already gone that way; what pins those screens now is their snapshot
baselines.

§1–§4 were reviewed against 0.0.4 on 21 August 2026 and §5 against 0.0.19 on 25 August 2026, both at
iPhone 13 Pro 390 × 844pt and iPad Pro 11″ landscape 1194 × 834pt, at Dynamic Type Large and
xxLarge.

Everything here stays inside the system idiom: semantic colours, SF Symbols, stock controls. Where a
control is wrong the review names the right one. Where the specification cannot be drawn at 390pt it
says so and shows the measurement.

## What is settled, and what is still open

| Section | Screen | Milestone | State |
|---|---|---|---|
| §1 | Server discovery | built | **applied** — the code matches this document |
| §2 | The worktree sidebar | M4 | built |
| §3 | The file selector | M5 | built |
| §4 | The continuous diff | M5 | **everything drawn is built** — the scroll, the viewed toggle, the collapsed bars and hunk expansion. The header's second form and wrap-on are not, and **syntax highlighting was never drawn at all** |
| §5 | Pairing — the entry, the scanner, the six words, the outcome | M4 | built |
| §6 | Deleting a worktree — the affordance on §2's row and the confirmation | 0.5.0 | **built provisionally, not drawn.** The prompt is [#52](https://github.com/fardavide/granita/issues/52) and has not been sent. Thirteen calls were made without authority and each is listed below to be overruled |

**§5 is numbered last and happens first.** It was reviewed four days after §1–§4 and takes the next
number rather than renumbering four sections that a dozen documents already cite; in the reader's
path it sits between §1 and §2, which is where its own prose puts it. Its four screens make §2
reachable — until 0.1.0 the worktree sidebar was built and nothing in the app could open it.

Two things the review could not decide from drawings, and that a device has to answer before §4 is
built:

- **The code point size.** Every measurement in §4 is taken at 11pt because that is what makes 51
  characters fit. Whether 11pt is readable at arm's length on a 6.1″ screen is not a thing a drawing
  can judge, and it moves every number in that section. Set it on the device first, then let the
  gutter follow.
- **Whether wrap-off survives on the phone at all.** A two-axis scroll inside a vertical scroll that
  must never reflow is the hardest gesture in this product. Build the wrap-off scroll **first** —
  before the collapsed bars and before focus mode. If it does not feel right, character wrapping
  becomes the default and half of §4's gutter arithmetic stops mattering.

## The four premises that were tested

| Premise | Verdict |
|---|---|
| Six fields on one iPhone row | **Does not fit.** Four survive at Large, three at xxLarge. The project name is the one that goes, and grouped mode is what makes that affordable |
| A compacted path inside a sheet | **Fits, with a rule** — head-truncated, indent clamped at depth 4. At depth 4 with 60 characters you read the last 30 |
| Two nested backgrounds behind mono text | **Fits, not as drawn.** In light at a 3× alpha ratio, yes. In dark, no — the word highlight has to be carried by the text |
| Wrap-off code plus two gutters at 390pt | **Does not fit.** Two number columns leave 41 characters, one leaves 51, neither is 80. Horizontal scroll is the primary interaction, not a fallback |

The sticky file header does fit, and is the only one of the four not to change: 28pt once the toolbar
hides on scroll, which is 3% of the screen for the one thing that says where the reader is.

## §1 — Server discovery

Six states, one navigation title, no invented controls. The shape was right; three things were wrong
and one of them was a bug the snapshot suite was asserting as correct.

### The row is a navigation link, not a labelled pair

A label-and-value pair resolves width pressure by giving the label what it asks for and dropping the
value onto its own line — correct for a settings row, wrong here, because the "value" was a
disclosure chevron. The third row's chevron landed under the text, left-aligned, 300pt from where an
indicator belongs. The whole row was also a button with a hand-drawn chevron in it.

A navigation link supplies the indicator, pins it to the trailing edge at every type size, gives the
correct pressed state, and draws no chevron at all once this list becomes a split-view sidebar.

**The name truncates in the middle, not at the tail.** Bonjour device names differ at the *end* —
"…MacBook Pro (work)" against "…MacBook Pro" — so tail truncation deletes the only distinguishing
part of the string.

**One line, not two.** The review's prose said two and its frame drew one, and one is what was meant:
a two-line limit does not truncate a long name at 390pt, it *wraps* it, which is the 68pt row the
same section rejects two paragraphs later. One line keeps every row the same height and the list
scanning as a column, and the truncation the frame shows is what a long name actually gets.

> Rejected: shrinking the name with a minimum scale factor — it fights Dynamic Type, which is the one
> accessibility promise this app has made. Rejected: a two-line wrap with the chevron centred — it
> works, but it makes a 68pt row out of a device picker used twice in the app's life.

*Should feel like* the Wi-Fi list in Settings. You do not read these rows, you recognise one and hit
it.

### Searching is distinguished from nothing-found by motion, not by copy

Both states were the same layout at the same weight in the same position, with twenty characters of
title changing and a symbol swapping. Held in one hand that reads as a redraw, not as progress.

**No spinner.** A progress view promises a finish and Bonjour has none. Instead the antenna carries
an iterative variable-colour symbol effect: stock, one line, and it makes arrival at a *static*
symbol the signal that searching stopped. The motion is the progress indicator; its absence is the
result.

**Nothing-found gets a "Search Again" button.** Permission-refused is not the only state with an
action. A reader who plugged the Mac in after the browse went quiet otherwise has one recourse, which
is to kill the app. The client's browser restart policy already exists, so the button maps to a real
mechanism rather than a placebo.

**One copy change, and it is the important one.** On a cold first launch the system's local-network
prompt appears *over* this screen, and the sentence behind the prompt is the one that has to earn the
tap on Allow. The old sentence did not mention permission at all. The new one names it first:
*"Granita needs permission to look on this network, and has to be running on a Mac that is on it."*
Same facts, ordered so the first clause answers the alert.

> Rejected: a determinate progress bar over a timeout — it invents a deadline the protocol does not
> have, and a bar that reaches the end and finds nothing is worse than silence. Rejected: merging the
> two states into one screen that mutates its own subtitle. Two unavailable-content views are the
> honest model; they just need to look like they happened at different times.

*Should feel like* AirPlay looking for a screen. Something is alive; when it stops being alive, you
noticed without reading.

### Never put the system's string in the advice slot

An unavailable-content view's description is the one line the reader will act on. Handing it the
error's localised description means the screen's advice is written by whichever framework failed, and
Network.framework writes badly.

Three slots, three jobs:

- **The description is ours** and always says the same two things: try again, and here is the one
  other thing it could be.
- **The action is "Try Again".**
- **The system's string moves to the bottom** at caption2, monospaced, tertiary and selectable — so
  it is copyable into a bug report and unmistakably not instructions. The raw network error code is
  appended, because it is the only part of that string a developer can act on, and here the reader is
  the developer.

**Route policy errors away from this state.** iOS reports a refusal one way to a first browser and
another way to every browser after it, so a genuine denial will sometimes arrive as a failure. When
the error is a policy error, render the refused-permission state instead. Being wrong in that
direction costs the reader one tap; being wrong the other way costs them the app.

> Rejected: hiding the system string behind a disclosure — a tap to reveal four words nobody can act
> on. Rejected: an alert — it demands an answer to a question the reader was not asked, then leaves
> the same empty screen behind it. This is a state of the screen, not an interruption.

*Should feel like* the app taking responsibility. The words are ours; the diagnostic is in small
print at the bottom where diagnostics go.

### The iPad is constrained, not stretched

A 1,150pt row pulls its two ends apart: the name at x=150 and its chevron at x=1,140, with nothing on
screen saying they belong to the same tap target. A row that wide stops reading as a row. The empty
space is the smaller problem.

One constraint, applied to the **whole screen** rather than to the list: a maximum content width of
420pt, centred, with the large title inside the same measure so the title's leading edge lines up
with the rows. Every state gets it, so the empty states stop being small things in a large room and
become a centred card. It is the iPad setup idiom — Apple TV pairing, Home hub setup, Migration
Assistant — and the phone layout is then literally the same layout at its natural width.

**The measure goes around the navigation container, not around the screen.** iOS draws a large title
in the navigation bar rather than in the content, so a frame applied inside centres the rows and
leaves the title pinned to the window's leading edge — the exact misalignment the measure exists to
remove. Whoever owns the navigation container applies it, and the snapshot suite clamps on the same
side so the baselines assert the alignment that ships. The one thing to watch: the navigation bar's
own background is clamped too, so a future screen whose content scrolls under it will show a 420pt
frosted strip. None of the six discovery states scroll.

> Rejected: rendering discovery as the sidebar of the eventual split view with a placeholder detail
> column — more code, and it shows a two-column shell for a product the reader has not connected to
> yet. Rejected: a form-sheet presentation. There is nothing behind it to dismiss to.

*Should feel like* the same screen as the phone, at rest in the middle of a bigger display.

### No second line on the row. A section instead. *(M4 — needs pairing history)*

A row deserves no second line before pairing, because there is nothing true to put on it. Host and
port are re-resolved every time by design; server version, project count and last-seen are all facts
the phone acquires *after* it connects. A second line here would promise detail the state cannot
keep.

Spend the pixels on order instead of on annotation. **A Mac this phone has paired with before goes in
a *Recent* section; everything else falls under *Other Macs*.** Two sections, no badges, no second
lines — and it degrades to a single unlabelled section when there is no history, which is what ships
until pairing exists.

**Identical names are not a problem to solve.** A Bonjour instance name is unique within a domain —
the system appends "(2)" itself — so two Macs both called "MacBook Pro" arrive already distinguished.
Do not build for a collision the protocol prevents.

> Rejected: a trailing "paired" checkmark — it decorates every row in the common case and says nothing
> in the rare one. Rejected: a model-specific symbol per Mac — the Bonjour record does not carry the
> model, so it would be a guess from the device name.

*Should feel like* a list you never actually read after the first week.

## §2 — The worktree sidebar *(M4, drawn)*

Six fields do not fit. What fits is **two lines and a trailing time**, and what makes it fit is
deciding that the four name sources are really two.

### Two name tiers, carried by the font

The reader does not need to know which of four fields won. They need to know one thing: *can I trust
this string to tell me what the agent did?* An alias can. A session summary can. A branch name
usually can. A generated worktree directory name never can.

**Render the fallback tier monospaced and tail-truncated** — the opposite of the Mac list in §1, and
for the opposite reason. A Bonjour name differs at its end, so the end has to survive; a generated
directory name is a mnemonic prefix followed by a ULID, and the ULID is noise while the prefix is the
only meaning in the string. So the front survives here. Everything else stays proportional.

Monospace says "machine string, there is no meaning in here" without spending a colour, and it is
already this app's word for *code*. One font-design switch encodes the whole question. No glyph, no
badge, no accent.

Alias against session suggestion needs nothing at all: a title and a sentence are different *kinds*
of string and read as such. A badge distinguishing them would answer a question no reader has.

**Truncate the suggestion in the view, not on the wire.** Keep the server's 60 characters — the rename
sheet prefills from them. Display at two lines, which at 390pt is about 44 characters of headline.
Two lines is the ceiling; three makes a 90pt row, and five of those is a wall of prose.

> Rejected: an SF Symbol per source — four glyphs to learn, three of which are noise. Rejected:
> italics for suggestions — in a list, italic reads as an error or a placeholder. Rejected: showing
> the directory name as a *second* line under a branch name — the one string the reader never wants,
> given twice the space of the one they do.

### What the row drops, and in what order

| | Field | When it goes |
|---|---|---|
| 1 | display name, headline, 2 lines | never — it is the row |
| 2 | last modified, trailing, tabular | never — 2 to 3 characters, and it is the sort key |
| 3 | `+n −m`, semantic green and red | never — it is how big the read is |
| 4 | files changed | first to go, at xxLarge with four-digit stats |
| 5 | project name | absent in grouped mode; the section header has it |
| 6 | pinned | never on the row in grouped mode; the section has it |

### Pins and git flags

A single Pinned section above the project sections is right, and the objection that a worktree then
appears away from its siblings is real. The fix is one field, not a different structure: **a pinned
row keeps its project name on line two even in grouped mode.** Then it is not orphaned, it is
annotated.

Because the section carries the pin, **no pin glyph on the row in grouped mode**. Flat mode has no
header to carry it, so there the pin is a leading filled-pin symbol at caption2, secondary. One or
the other, never both.

Of the four git flags, one and a half earn pixels:

- **Primary checkout earns a word.** "Primary checkout" on line two is the reader's own mental model:
  this is the one the agent *did not* work in. It also explains why that row usually has no changes,
  which is otherwise the most confusing row in the list.
- **Detached earns a word conditionally** — only when the display name fell through to the directory
  name. Then it is not a flag, it is the answer to "why is this row a random string?". With an alias,
  detachment is irrelevant to reading a diff and stays off.
- **An unborn head earns the stats slot**, not a flag: "no commits yet" where `+n −m` would be.
  Everything compares against the empty tree, so the real numbers are the whole repository and they
  are a lie about what changed.
- **Locked earns nothing, ever.** Git plumbing with no bearing on reading a diff, and v1 cannot prune
  worktrees, which is the only operation it would block.

> Rejected: floating a pin to the top of its own project section — you still have to find the project,
> which is the work the pin exists to skip. Rejected: duplicating the row in both places — a row that
> appears twice is a worse bug than a row that appears once in a surprising place.

### The title is the Mac's name, and it is inline *(measured 25 August 2026)*

§5 ends by saying the reader lands on "the worktree list titled by the Mac's name", and this is that
title. It said *Worktrees* for one release, which is the one thing the reader already knew — they had
just tapped a Mac to get here.

**Inline rather than large, and that is a departure this screen paid for rather than chose.** The
name is a Bonjour device name, and §1 derives truncation from what a string *is*: those differ at
their end, which is why the Mac list truncates them in the middle. A large title cannot be told to do
that. At 34pt bold it holds about sixteen characters at 390pt and fewer in the 320pt sidebar, and it
drops the rest off the tail — *Davide's 16-inch MacBook Pro* rendered as *Davide's 16-inch Mac…* on
the phone and *Davide's 16-inch…* on the iPad, which loses exactly the half that says which Mac. At
17pt semibold the whole name fits, and the list gets back the 52pt a large title spends on every
scroll.

> Rejected: keeping the large title and accepting the truncation — defensible, because the reader
> chose this Mac one screen earlier, and indefensible the moment a second Mac is serving, which is
> the case the title exists for. Rejected: a custom principal toolbar item that scales the name down
> to fit — a hand-rolled title, for a control the system already has, to preserve a size nothing in
> the design asks for. Davide's call, 25 August 2026, against two rendered layouts.

### The mode control is a toolbar menu, not a segmented picker

This is the strongest single recommendation in §2. A segmented picker is a permanent 32pt band plus
16pt of padding — 48pt of every scroll, forever, for a preference set once. It also lands directly
above the Pinned header, so the first thing the reader sees is two rows of chrome.

One toolbar menu holding an **inline picker**: the mode stays a picker in code and the options render
as checkable rows. The clincher is that there is a third preference and probably a fourth, and three
toggles cannot be three segmented controls but are three menu rows without a redesign. On iPad the
same menu sits in the sidebar's toolbar.

**Flat mode promotes the project name** onto line two ahead of the file count, where the section
header used to be. It is the one field the list cannot lose — without it a flat list of agent
sentences has no idea what codebase it is talking about.

> Rejected: sections in a searchable scope bar — a scope bar filters, and this does not filter.
> Rejected: a leading-edge sidebar toggle button — two states with no labels, so the reader has to
> press it to learn what it does.

*Should feel like* Mail's sort menu. You touch it in week one and then forget it exists.

### The rename sheet previews its own result

One sheet at the medium detent, a navigation stack inside it, Cancel and Save. Nothing here is a new
control.

**The one idea worth keeping: the section footer always states what the row will read after Save, and
it updates live as the field changes.** That single sentence answers all three cases at once. An
empty field is not a mystery — the footer says what it will fall back to. The placeholder is the
derived name, so an empty field even *looks* like the fallback it will produce.

**Clearing an alias needs no destructive button.** The field's clear glyph plus Save is the whole
gesture, and the footer confirms it before the tap. A red "Remove alias" row would put a destructive
treatment on an operation that touches no git state and is reversible in four seconds.

**Do not prefill with the suggestion — offer it.** This is the one place this document contradicts
`SPEC.md` outright, and the departure is recorded in [`decisions.md`](decisions.md). A prefilled field
means the reader's first act is to select-all and delete 51 characters on a phone keyboard, and it
hides the difference between "I accepted the agent's summary" and "I named this". Offering it as a
tappable row costs one tap for the accept case and saves the delete for every other case. The row
shows the suggestion at full length — two lines if it needs them — because this is the only place in
the app where all 60 characters are worth reading.

With no suggestion the section is absent and the footer says why in the reader's terms: no session,
or detached, or both. That turns an empty sheet into an explanation.

> Rejected: an alert with a text field — it cannot hold a two-line suggestion, cannot show a live
> footer, and gets clipped by the keyboard. Rejected: a full-screen push — renaming is a four-second
> job and does not deserve a navigation event.

*Should feel like* renaming a photo album. You are never unsure what will be on the row when you let
go.

### Hide the quiet worktrees, and say how many you hid

Worktrees with no changes are hidden by default, and the count goes in the list's footer as a
tappable line: *"6 worktrees with no changes are hidden. Show them."* That kills the objection that
the menu bar count and the phone's count would silently contradict each other — the list now *states*
what it is hiding, so the two reconcile on screen. The permanent version of the same switch lives in
the toolbar menu.

> Rejected: showing them dimmed — dimming reads as disabled, and a reader who taps a dimmed row and
> gets a working screen learns to distrust dimming everywhere else. Rejected: a collapsed "Quiet"
> section per project — more chrome than content on a slow day.

The four states, briefly:

- **No projects enabled.** An unavailable-content view with **no action**, because there is nothing on
  this device to tap. The description names the exact menu — "Granita's menu bar item, under
  Projects" — so the sentence *is* the instruction. A disabled button, or one opening a "do this on
  your Mac" modal, would be a control that cannot act.
- **Enabled but all clean.** Same control, and here the action is real: "Show them anyway". The count
  in the description is what makes this state trustworthy rather than alarming.
- **One project only.** Not a special case. Leave grouped mode on and let the single section header be
  the project name. Auto-switching to flat would make the list change shape when a second project is
  added, which is a worse surprise than a redundant header.
- **312 files beside zero.** No treatment beyond writing "no changes" where the numbers would be. A
  312-file row is visually heavier than a clean one without any help, and that is the correct
  hierarchy — the big one is the one you came for.

### iPad: 320pt makes the same row work harder

A split-view sidebar is 320pt at this size class — *narrower* than the iPhone's 390. The iPad is the
harder layout for this row, not the easier one, and the drop order above is what saves it. Two things
come free from using the right control: a navigation link draws no chevron in a sidebar and gives the
selected row a tinted selection instead, and the empty detail column is an unavailable-content view,
the same control as every other empty state in the app.

*Should feel like* Mail with the mailbox list open. The sidebar is a place you look, not a place you
work.

## §3 — The file selector *(M5, built in 0.3.0)*

**What building it changed, and what it did not.** Every call below survived except two, and both are
recorded where they are made: the truncation footer says what was *served* rather than what exists,
because the total is not on the wire; and on iPad the permanently-visible column is a column of the
diff screen rather than a third column of the split view, because a real third column means
selection-driven navigation on the one path this app has proven and cannot press. Both are in
[`decisions.md`](decisions.md), with the iPad measure — 320 / 320 / 554 — photographed rather than
argued.

**The viewed mark ships with §4's toggle behind it**, which is a scheduling call this section forces:
a mark that reports a state nothing in the app can write is a column that is empty forever. See §4's
*Viewed is tapped, never inferred*, which is where the writer lives.

### Keep the sheet. Make it a drawer, not a modal.

The selector earns its screen, but not as a modal. Enable background interaction up through the
medium detent and drop the dimming. The diff keeps scrolling behind the sheet, tapping a file jumps
the scroll *with the list still open*, and the reader walks a change set file by file without a
dismiss-present cycle between each one. That is a materially different tool from the modal version,
and it is one modifier.

> **The drawer comes down to medium when a file is chosen** *(1 September 2026)*. Background
> interaction is enabled *up through* medium, which is the modifier's own limit and not a choice — at
> the large detent the sheet covers the phone and the diff behind it is neither visible nor
> scrollable. So a tap at full height jumps a scroll nobody can see, which is this project's dead
> control wearing a detent: the row did something, and the reader has no way to know. Choosing a file
> therefore writes the detent back to medium. **Reduced rather than dismissed**, which is Davide's own
> preference and the weaker intervention — shutting the drawer would cost the reader the list they are
> working down, and the drawer exists so it need not be reopened between files. The height is the
> model's, not the sheet's, for the reason every other one here is: a control whose only effect is a
> `@State` two layers up is a control nothing can be asked about.
>
> **And the row shows that it was pressed.** Its effect happens somewhere else on screen — behind the
> sheet, or off the top of a long change set — so without a press highlight the one control on this
> screen gives the reader nothing back. `.plain` draws none inside a `List`, and the automatic style
> tints the filename with the accent colour, which reads as a link. A fill behind the label at the
> press, edge to edge: the row's insets moved inside its own label so the highlight reaches the bezel
> rather than stopping 12pt short at each end and reading as a chip.

> Rejected: a jump-to-file menu in the diff toolbar. Cheaper, and it loses on three counts. A menu
> cannot indent, so directory grouping cannot be expressed in it. It cannot scroll to 300 items
> usefully and cannot be searched. And it cannot show *viewed* across the whole set, which is the
> selector's second job and the only place the reader sees how much is left. A menu answers "jump";
> it does not answer "where am I in this review".

### What survives on the row, in order

**name → status → viewed → stats.** Stats go first when width runs out, because the file header in
the diff repeats them 200ms later. Then viewed collapses into the name going secondary — a dimmed
filename already means "done" and needs no glyph. The floor is a status letter and a filename, and at
390pt inside a sheet at depth 3 that leaves about 200pt for the name, or 24 characters. Most Swift
filenames in this repository are longer, so the name head-truncates too.

**The status letter and the viewed mark share a row, but not an edge.** Status leads, because it is
part of the file's identity and it aligns into a column the eye can scan down. Viewed trails. Both on
the trailing edge is the two-checkboxes problem.

**The viewed mark is not a control in here.** A 32pt row inside a sheet cannot hold two tap targets
without generating mis-taps, and the row's job is to jump. It reports state. The toggle lives in the
diff's file header, where the reader is when they finish a file.

### The indent clamps at depth 4, and paths head-truncate

At depth 4 the indent is 56pt, the disclosure triangle takes 22pt, and about 284pt is left — 33
characters, head-truncated. A 77-character compacted path shows its last 32, which is the part that
identifies it.

### Seven statuses, four colour treatments

| Letters | Treatment | Why |
|---|---|---|
| added, untracked | green | To a reader of uncommitted work the difference is git bookkeeping. Same treatment, different accessibility label |
| modified, type-changed | **no colour at all** | Modified is four rows in five; colouring the default case spends the palette on the thing that carries no information |
| deleted | red | Matches the deletion tint in the diff below it |
| renamed | indigo | Not green — a rename adds no code, and reading it as an addition is the mistake this letter exists to prevent |
| conflicted | orange | The only status that also survives into the file header in the diff. It is the one status that means *you must look at this* |

### Directories aggregate only while they are shut

A collapsed directory carries the summed `+n −m` of everything inside it; an expanded one carries
none, because its children are right there with their own numbers and the parent's total becomes
noise you have to mentally subtract. Same for viewed: a checkmark on the directory when every
descendant is viewed, at either state, because "this whole subtree is done" is the most useful thing
the tree can tell you. Above roughly 20 children a directory arrives collapsed, which is what makes
the 80-directory case readable.

**Flat mode is the same row with a different label**, not a different design. The path splits into two
runs in one text view: the directory prefix secondary at footnote, the filename primary at
subheadline, head-truncated so the prefix erodes and the filename never does. Status, stats and the
viewed mark are untouched — one row implementation, two labels.

The states:

- **One changed file.** No tree. At three files or fewer, or a single directory, render flat and do
  not offer the toggle — a tree over one file is two rows of ceremony for one row of content.
- **Over 1,000 files.** A plain footer line, not an alert. The server already returns a truncation
  flag and a reason; print the reason. Say "not served" rather than "load more", because the server's
  limits will not serve them and a button that cannot succeed is worse than a sentence.
- **Everything viewed.** Not an unavailable-content view — the files are still there and still
  openable. The list renders normally with every name secondary and every check set, and the footer
  says "All 12 files viewed". The reader's next move is to leave, and the app should not congratulate
  them.

*Should feel like* the Xcode navigator, minus the parts of the Xcode navigator nobody uses on a phone.

## §4 — The continuous diff *(M5 — everything but highlighting, wrap-on and the header's second form)*

**What is built, and what deliberately is not.** The one continuous scroll, the gutter, the line
tints and the word segments, the hunk bands and a sticky file header landed in 0.2.0; the viewed
toggle in 0.3.0; **the collapsed bars and hunk expansion in 0.4.0**. What is left is syntax
highlighting, the wrap-on mode and the header's second form, and each is absent rather than disabled
— nothing on that screen is a control that does not work.

Five calls below were changed by building them, and each says so where it is made: the row splits
into two view trees, the file header ships in one form, a shut file's bar replaces its header rather
than sitting under one, the bar for a *viewed* file says "viewed" and cannot say how long ago, and
the band grows to 44pt only where it carries a control. All are in [`decisions.md`](decisions.md).

### The file header sticks, and costs 28pt — but only if the toolbar goes

> **Built in one form, not two** *(26 August 2026)*. A pinned section header keeps its slot in the
> lazy stack while a copy floats at the top, so a header that is *shorter* when pinned changes the
> height of a slot above the viewport — and everything below it, the reader's own content included,
> moves. That is the reflow SPEC §10 forbids, so what ships is the pinned form always: status letter,
> head-truncated path, stats, and CONFLICTED where it applies. What that costs is the second line,
> which this section itself calls orientation for arriving rather than for staying, and arriving is
> what §3's selector is for. Provisional pending a device. Rejected: two forms with a constant slot
> height, which SwiftUI gives no way to express, since the floating copy *is* the slot's view.

It has to stick. It is the only thing that answers "where am I" after thirty seconds of scrolling,
and reading the path off the nearest hunk heading is not an answer because hunk headings are function
names, which repeat.

**Two forms, one header.** In flow it is two lines: path, then status, stats, language and hunk count.
Pinned it reduces to a single 28pt line — collapse chevron, status letter, head-truncated path,
stats, viewed toggle. Nothing is lost that the reader needs while *inside* a file; the second line is
orientation for arriving, not for staying.

**Then the toolbar has to hide on scroll**, restored on scroll up, and the Files button comes back
with it. Sticky header plus gutter plus toolbar is most of a phone; sticky header alone is 28pt of
844, or 3%.

Implementation that keeps the no-reflow rule intact: one section per file in a lazy stack with pinned
section headers. Pinning is a rendering position, not a layout change, so nothing above the finger
moves.

> Rejected: putting the path in the navigation title and updating it as files pass — it fights the
> toolbar hiding, and a title that changes while you scroll is the single most reflow-*feeling* thing
> you can do to a reader even when nothing reflows. Rejected: a floating path chip — a sticky header
> that has given up its collapse control and its stats.

### One gutter column, never empty, with a marker beside it

> **The interleaved column this section rejected is what ships, because rule 2 answers the objection**
> *(1 September 2026)*. What follows replaces "keep the new number", and the reversal is in
> [`decisions.md`](decisions.md). The old call left a **deletion with no number at all** — the diff
> design review's only correctness bug — because a deletion has no new-side number and the column
> held nothing else.

SF Mono at 11pt advances 6.6pt per character. A four-digit number is 26.4pt; with 9pt of trailing
space and 4pt of leading inset, one column is 39pt and two are 78pt. At 390pt with a 12pt trailing
inset that is **51 characters of code with one column and 41 with two**. Neither reaches 80, which is
the honest headline of the section — but 41 is not a diff viewer, it is a keyhole.

**One column, carrying whichever side the row is on**: a deletion shows its old number, an addition
and a context line show the new one, and a conflict marker shows whichever it arrived with — the
parser resolves that kind from the *text* but numbers the line from the diff prefix, so those rows are
numbered like the ordinary lines they came in as. Only `\ No newline at end of file` has none, and it
is not a line of the file. Width is computed per file from the **larger** of the two sides' maxima, so
a file with a hundred lines cut from its end still fits its four-figure old numbers.

**Beside it, a 12pt `+`/`−` column at full saturation.** This is what makes one column honest, and
the two calls stand or fall together: the marker says which side you are reading, so the figure no
longer has to. It is also the only thing on the row that survives red-green colour blindness,
sunlight, and a chat client that dims the screenshot — colour alone was the review's second fault.
Both the figures and the marker sit **outside** the horizontal scroll with the tints; a marker that
scrolled away would leave the row saying nothing on exactly the long lines the reader scrolled to
read. Code therefore starts at 48pt rather than 19pt, which is about **54 characters** instead of 57.

> Rejected: the marker alone, keeping today's column — it leaves the unnumbered deletion, which is
> the bug. Rejected: two columns on the phone, which is `SPEC.md` §10 taken literally and the keyhole
> measured above. Rejected: shrinking to 10pt to fit two columns — 57 characters, and code you have
> to squint at.
>
> The **iPad loses its second column too.** This section used to argue that both columns there were
> "the whole reason the phone can afford to drop one"; with an interleaved column that argument has
> nothing left to support, and the review's own iPad frame draws one 44pt column. What the iPad
> spends the room on instead is **12pt code** — about 110 characters in an 846pt pane, so nothing in
> an ordinary change set is cut at all.

### Rows loosen and the chrome tightens

> **Added by the diff design review** *(1 September 2026)*. Its fourth fault: 43pt of grey slab
> standing for two lines of code drawn at 13.7pt. "The chrome is loose and the content is cramped,
> which is backwards."

Code rows go to **18pt** — the font's own line height plus 4pt of leading, so the code size stays a
setting rather than becoming a constant. The file header goes to **46pt** and carries two lines where
it carried one. The screen holds about the same number of code rows and reads at half the effort.

> **The band's 26pt did not survive the expander** *(1 September 2026, 0.6.1)*. This paragraph used to
> take the hunk band from 43pt to 26 and buy its control's hit area horizontally. The band is gone —
> what replaced it is a torn row that exists only where lines are missing, and it is **44pt**, because
> in two of its three forms the row itself is the control. The saving the rule was after is bigger
> than the one it costs: the band was drawn above every hunk, and a tear is drawn only across a gap.

**Files are separated by 10pt of page**, which is the review's seventh fault: without it a collapsed
bar floats in the same 8pt of white as the closing brace above it, and a header sitting directly under
a code row makes that code read as belonging to the file below. The gap goes at the *foot* of a
section, never the head, because the head of a section is the pinned header.

> **And the page is a colour, which is what 0.6.1 had to add before the gap could be seen**
> *(1 September 2026)*. 0.6.0 built the 10pt and left it clear over a screen whose background is the
> same white as the rows, so what shipped was ten points of white between two white files — Davide's
> first note on it was "there's no spacer between files". The review draws the files as **cards on a
> grouped page**: the scroll takes the grouped background, each file's header, bar and lines take the
> opaque one, and the gap is the page showing through. One colour answers every boundary — bar to
> bar, bar to header, and under the last file — where a rule per boundary would be four and would
> still have to be re-decided each time a file shuts. The pair is the **grouped** one — the plain
> `systemBackground` over `systemGroupedBackground` is white on grey in light and black on black in
> dark, which fixes one appearance and reproduces the fault in the other. Rejected: a `Divider` per
> gap, which draws a line where the review draws a space, and says nothing under the last file.

**There is no hunk band.** What stood above every hunk is now a torn row drawn across a gap, and it
has its own section below — *The expander is a tear*.

> **Two calls were made here and then overtaken inside one release** *(1 September 2026, 0.6.1)*, and
> they are kept because the second review answered the first: the band was drawn with
> `.background(.quaternary)`, which resolves the quaternary **label** rather than the quaternary
> **fill** its own prose named, so a strip standing for skipped lines was the loudest thing on a
> screen whose subject is the code — Davide's note was that its colours were wrong. It was corrected
> to `quaternarySystemFill` with a hairline at each edge, and then the band stopped existing: an
> expander is accent-tinted, because it is a control rather than chrome. The other call — that a band
> with no heading and no gap either side is not drawn — survived intact and grew into the rule that
> *every* row is a gap, so a row with nothing missing behind it cannot exist to be suppressed.
>
> **What neither fixes, and it is a defect rather than a call:** the last hunk of every file reports
> no gap below it, because the Mac derives a file's new-side length from that hunk's own end rather
> than from the file. The *remainder of file* row is therefore built, tested and currently
> unreachable. In [`decisions.md`](decisions.md); the fix is the Mac's, not this screen's.

**The marker column has six points after it**, so the code clears the `+` and the `−`.

> **Added in 0.6.1** *(1 September 2026)*. The glyph is centred in a 12pt column, which leaves about
> 2.7pt before the code — and on a line with no leading whitespace `−public struct` read as one
> token, which is the opposite of what a marker at full saturation is for. Six points is what §4's
> own arithmetic has always implied: a 30pt figure column plus a 12pt marker against a code origin it
> puts at 48. Davide: *"`+/-` must have padding to the right"*.

**A side that changed nothing is not printed.** `+84 −0` is `+84`, `+0 −26` is `−26`, and a file
whose change set says `+0 −0` shows no counts at all.

> **Added in 0.6.1** *(1 September 2026)*, and it is §3's *modified gets no colour* argument applied
> to a number: `+0` is the field carrying no information. On the two rows that carry it — a binary
> file and a rename that changed nothing — it was the whole of what the row said about the change,
> and it was wide enough there to push the counts under the bezel. What is left is a figure a reader
> can only read one way. Rejected: dimming the zero, which spends a treatment on saying *ignore this*
> where absence says it for nothing.

**Nothing in the row ends against the bezel.** Four points after the 44pt slot, and the slot is drawn
whether or not there is a mark in it.

> **Added in 0.6.1** *(1 September 2026)*. A `Group` wrapping an absent `if` is an `EmptyView`, and a
> frame around one reserves nothing — so the shut bar's mark slot existed in the source and never in
> the layout, and an unread file's counts ran under the right bezel with the last figure cut off.
> `+1,240 −318` on the one row a reader most needs to size. The glyph is drawn **clear** at rest
> instead, which is the treatment §3's own row already uses and for the same stated reason.

**The header and the bar that replaces it draw one column.** The chevron sits in a stated 12pt slot
and the whole row is spaced at 8.

> **Added in 0.6.1** *(1 September 2026)*. `chevron.down` and `chevron.right` do not measure the
> same, and the header spaced its trailing run at 0 where the bar spaced its at 8 — so shutting a
> file moved its status bar, its name and its counts by a few points each. Small enough to be
> deniable in a single row and unmistakable down a change set, which is exactly the class of thing
> the review keeps finding. Both numbers are stated on the header and read by the bar, because the
> two rows are one row in two states.

### The file row is a name over a place

> **Added by the diff design review** *(1 September 2026)*, replacing one line of head-truncated path.

The filename gets its own line and is **never truncated**; the directory goes under it in mono, and
**truncates in the middle** so both of its ends survive. That is a different answer from §3's
head-truncation and it is derived the same way — from what the string is. A path's tail is the
filename, so head-truncation keeps what identifies it; but once the filename is on its own line the
second line is a *place*, and both of a place's ends carry information.
`…out/Presentation/Models/AboutState.swift` deletes the module, and the module is what tells eleven
files apart when three of them live in a folder called `Models`.

The status **letter** is replaced here by a **3pt colour bar** — see `decisions.md` for why modified
now carries one when §3 says it carries none. The letter stays in §3's selector.

### Three of the review's calls are recorded here rather than built

> *(1 September 2026)*, and two of them the review itself marked as not-yet-answerable.

**The screen keeps its inline title.** The frames draw `main` as a large title over a subtitle
reading `working tree · 11 files · +105 −12`. The title stays inline for the reason this section
already gives: 34pt bold holds about sixteen characters and a worktree's name here is an agent's
session summary, which is a sentence. The frames assumed a branch name.

**The subtitle's totals are not built, and the review says why.** Its own note calls `+105 −12` a
placeholder — "the seven files I can see sum to +102" — so there is nothing to render yet. A
change-set total is a real thing the Mac could send; it is not on the wire today.

**The `+n −m` counts keep no proportion**, which the review raises and rules out of its own scope:
`+95` and `+1` look equally significant, a five-segment bar would fix it, and that is a new control.
It stays a question for Davide rather than a call.

### Reviewed is quiet, closed, and a 44pt target

> **Added by the diff design review** *(1 September 2026)*. Its eighth fault: a 21pt ring hard against
> the right bezel, identical on every row, on the one control a reader presses once per file.

44pt square. Checked fills **green** — agreeing with the `+` in the gutter and the added-line tint —
collapses the file, and drops the row's *information* to 45%. **The toggle itself does not dim**: it
is the control for undoing the state it reports, and dimming it hides it exactly when it is wanted.
An eleven-file pass therefore leaves a visible trail, and the unreviewed files are the loud ones.

### The word segment is a background, and the ratio is what is stated

> **Reverted to `SPEC.md` §10, and the ratio is what survived** *(28 August 2026)*. This section
> originally read *"in dark mode the word segment is carried by the text"* and inverted the emphasis:
> unchanged runs down to secondary, the changed run at full-strength label. It reads well and it
> spends the one property the syntax highlighter needs — a lexer colours text, and a line whose text
> colour already means *this part changed* has nothing left to say `keyword` with. The review saw the
> edge of this and never drew the two together; §4 has no highlighting section at all. Davide settled
> it: *"Changed words should have different background color, instead of text color"*, which is what
> the specification had asked for all along. In [`decisions.md`](decisions.md).

"Stronger" is a ratio, not a colour, and that is the half of the original argument that was right.
Row tint at 10% of the semantic green or red in light and 16% in dark; below about 3× the segment
stops being a second layer and becomes a slightly damp patch.

**So the ratio is written down and the alpha is solved from it.** Two translucent layers do not add,
they composite — `1 - (1 - t)(1 - s)` — so the fixed 28% the review measured reads as a *different*
multiple of the row in each appearance, which is the drift it rejected the treatment for. Pinning the
ratio instead puts the changed run at three times its row's tint in both: about 22% in light and 38%
in dark. That is what makes the treatment survive the dark mode this section was written to say it
could not, and the baselines are what say so.

> Rejected: underlining the changed run — it collides with the syntax highlighter and disappears under
> a descender. Rejected: bold — SF Mono keeps its advance when bold, so it is technically safe, but
> bold already means "keyword" to anyone who reads code. Rejected: one alpha for both appearances,
> which is the version of this the review measured and correctly refused.

### A collapsed bar must say why it is shut

> **Built in 0.4.0, and it goes where the header goes** *(26 August 2026)*. A shut file is the bar
> in the section header's slot with nothing under it, rather than a header over an empty section —
> which keeps two rows where this section draws one and leaves the reason nowhere to live. A shut
> file is 44pt and not one row more, which is what makes collapsing worth doing.
>
> **The viewed bar says "viewed" and cannot say how long ago.** The Mac stores a mark as the content
> hash it was set against and keeps no time beside it, so the elapsed reading is a number the phone
> would have to invent — the same call as §3's truncation footer, and the same reason.
>
> **A fifth case this section does not draw: the reader shuts a file by hand.** No reason line, so
> the bar is one line rather than two. Telling someone they shut a file they have just shut is a line
> that says nothing. And the two chevron-less rows are drawn **without** the faded chevron the frame
> shows, because a faded chevron is still a chevron.

44pt, and four things: status letter, head-truncated path, stats, and — the one the specification does
not name — **the reason**. "viewed 4 minutes ago", "1,558 lines · Load diff", "binary · no diff to
show", "renamed from … · no content change". Without the reason the reader has to open a file to
learn there was nothing in it, which is the exact cost collapsing was supposed to save.

A binary file and a rename with no content change get **no chevron at all**. There is nothing behind
them, and a disclosure control that discloses nothing is the smallest possible lie.

**The bar is also the fetch.** `SPEC.md` §10's *Load diff* is only true if the diff was not fetched,
so the scroll steps over every file it is drawing shut and opening one asks for it. That is why the
affordance is the whole row rather than a word.

### The expander is a tear, and the tear goes where the lines are missing

> **Redrawn, and it replaces the band rather than restyling it** *(1 September 2026, 0.6.1)*. This
> section used to read *"expansion lives on the trailing edge of the hunk header"*, and everything in
> it followed from the band being a header that happened to carry a control. It is the other way
> round now: the row **is** the gap, and where the gap sits decides the rest. Every paragraph below
> replaces one above it, and the reversals are in [`decisions.md`](decisions.md).

**A bar says a control is here. A tear says something is missing here.** The second is the fact a
reader needs while reading, and it is the one that survives being skimmed — a broken edge registers
before any label does. So the row is torn on the side the content is missing from, and that single
rule draws all three forms.

| Where the gap is | Torn | What it says | Controls |
|---|---|---|---|
| Above the first hunk | Top | git's heading for the hunk below — the declaration you are inside, which is what arriving in the middle of a file loses | The whole row |
| After the last hunk | Bottom | *remainder of file* — there is no declaration to name below a change, so it names its destination | The whole row |
| Between two hunks | Both | the count, moved into the label | Two 44pt controls, up and down |

Accent-tinted rather than grey: 5% of the accent in light and 10% in dark, a hairline of it at each
edge, and the tear a denser wash of the same hue cut with a scallop every 9pt. The label is a
darkened accent in light and a lightened one in dark, because 10pt type on a 5% wash of its own hue
is at the edge of readable. Every row carries a count.

**The glyph moves into the gutter, which this section used to forbid.** It refused the leading edge on
the grounds that "a glyph there reads as a line number" — true of a chevron, and the reason this is
not one. An arrow over three short rules *is* line numbers, near enough: the rules stand for the rows
that are not being drawn, which is exactly what the column is empty for. The two-way row has no glyph
at all, because there is no single direction to point in; its two controls say it instead.

**There is no fourth state.** At the first line of a file there is nothing above to reveal, so the row
is **absent** — not drawn greyed out. "A disabled control that can never be enabled is just a label,
and this one would sit at the top of every file you open."

**Twenty lines a press**, which is about a third of a phone screen at 11pt: enough to see what
encloses a change, little enough that the line the reader was on is still on screen afterwards. The
count on the row is the whole gap, not the window one press opens.

> **"Expand all" is not built**, and neither is the menu it lives in. That menu is also where *Mark
> everything above as viewed* and *Open on its own* belong, so it arrives whole or not at all.

**Conflict markers get the orange row and the file gets a badge.** They arrive as ordinary diff lines,
so the parser's conflict-marker kind is the only thing that makes them findable — a full-width warning
tint, the marker text at semibold, and a CONFLICTED badge in the file header so the reader knows
before they scroll. This is the one status worth a badge.

### Every disclosure moves, and it moves on the platform's own curve

> **Not the review's call — this repository's, in 0.5.2** *(31 August 2026)*. The design review drew
> the shut bar, the open header and the expand control and said nothing about how one becomes the
> other, so the first four releases did it in a single frame. Davide's verdict on that was "it looks
> terrible with the UI jumping", and he is describing the same defect this whole section is built
> around arriving from the one direction nobody guarded: **the reader's own press.** No-reflow is a
> rule about content moving *unasked*; it has never been an argument for a layout that teleports when
> it is asked. Without motion the reader cannot link where a file was to where it went, so the screen
> reads as replaced rather than changed and they have to re-find their place.
>
> **Four sites, one curve, stated once** — shutting or opening a file in §4's scroll, expanding a
> hunk's context, and opening or shutting a directory in §3's selector. The curve is the platform
> default. Rejected: a hand-tuned spring per site, which is four answers to one question and four
> edits when it is refined; rejected too, the 0.2s ease §4's jump-to-file already uses — that one is a
> *scroll* landing, timed against the baseline that photographs it mid-flight, and this is a layout
> opening and closing. The default also honours Reduce Motion without any of these views asking.
>
> **The baselines cannot see this and never will.** A snapshot photographs a settled state, and every
> one of them stayed green across all four releases that shipped the jump. It is checked by pressing
> the control.
>
> **Corrected in 0.5.3** *(31 August 2026)*: 0.5.2 attached §4's curve to the two halves of a file's
> section rather than to the scroll that holds them, and Davide pressed it and saw the hunk expansion
> move while opening and shutting a file did not. An animation scoped inside a section animates that
> section's own contents; the *other* files — everything that has to travel when one of them shuts —
> are laid out by the stack above it, and outside every scope the section could declare. So the curve
> belongs on **the container that lays out the movement**, keyed on the collapse state of all the
> entries: the lazy stack in §4, the list in §3, the file's own column for a hunk expanding. That §3
> and the hunks were right by accident is why only one of the four sites was visibly broken — and why
> a fade over a snapping layout is not a smaller version of the fix, it is the defect wearing a
> costume.

### Viewed is tapped, never inferred

> **Built in 0.3.0, in the file header and nowhere else** *(26 August 2026)*. The circle at the end of
> the header is the only writer there is, and §3's row beside it reports rather than acts — which is
> that section's call about a 32pt row and two tap targets. What is **not** built is the file
> collapsing once it is marked, which `SPEC.md` §10 asks for: that is the collapsed bar, and it is
> still drawn rather than built. What the toggle does today is perceivable in three places — the
> circle fills, the selector's row dims and takes a check, and the footer counts — so it is a control
> that works rather than one that waits. *"Mark everything above as viewed"* is not built either; it
> belongs to the header's menu, which arrives with collapse.

The tap is the only writer. This app has exactly one job — telling you whether you have read the code
— and an inferred "viewed" that fires on a fast flick is the app lying about the only thing it is
for. Content-hash keying makes a *stale* mark self-correcting, which is elegant; it does nothing
about a mark that was wrong when it was written.

The middle ground is worth having, because scrolling past thirty small files and tapping thirty
circles is real work: **"Mark everything above as viewed"** in the file header's menu. Inference on
demand — the reader asserts it, so it is still their claim.

> Rejected: inference with an undo — undo on a state that was set silently is a control for a mistake
> the reader does not know they made. Rejected: a hybrid that infers only for files under 20 lines —
> two rules for one flag, and the reader cannot tell which one applied.

### Cut focus mode on iPhone

On iPad focus mode is not a feature, it is the third column — you get it by having a split view at
all, and it earns its existence by costing nothing.

On iPhone it is a second reading surface with its own scroll state, its own gutter, its own
previous/next chrome and its own bugs, for a reader whose continuous scroll already has a collapse
control and a file list one tap away. **Cut it from M5** and see whether anyone asks. If it does ship,
it must not be the tap target on the file header: **tapping a header with a chevron on it has to
collapse the file**, or the chevron is decoration. Focus mode belongs in that header's menu, as "Open
on its own".

*Should feel like* your own claim about your own reading. Nothing in this app should ever tell you
that you read something you did not read.

### iPad: 554pt of code is where this product is pleasant

Three columns at 320 / 320 / 554. The diff column at 11pt SF Mono with **both** gutters is 72
characters — the first layout in the app where wrap-off is not a compromise. Both line-number columns
survive here, which is the whole reason the phone can afford to drop one: the two devices are not
showing the same gutter, and that is fine, because a line number is a lookup key rather than content.

Two consequences: the selector column is permanently visible, so the medium-detent sheet exists only
on iPhone — one code path, two presentations, and the tree view itself is identical. And the third
column is where focus mode lives, reached by selecting a file in column two rather than by tapping a
header.

*Should feel like* a review tool. The phone version should feel like the same tool, carried.

## §5 — Pairing *(M4, built in 0.1.0)*

Reviewed on 25 August 2026 against 0.0.19, at the same two layouts as §1–§4. Four screens, twelve
states, and **nothing hand-built**: seven unavailable-content views, one text field, one progress
view, one capture preview, three pushes. The review's own count, and it is the reason every call
below is about hierarchy and sequence rather than about a look.

**Twelve was the review's count and there are thirteen.** §5.7 is the one a real iPhone found four
hours after the slice shipped, and it is the one state here that no drawing could have anticipated,
because nothing in the flow could produce it until a bound was put under the sequence.

One thing the review found that no frame could draw, and it is the section to read first: **the two
credentials are not peers.** [§5.6](#56--the-six-words-carry-no-key-and-the-screen-says-so) is
where that goes, and it is what orders the two buttons on the first screen.

### The entry screen exists for the Mac, not for the choice

The obvious reading of this flow is *camera or words*, and the obvious build is to open the
viewfinder the instant a Mac is tapped. Drawn in sequence, that does not survive: **at the moment
the reader taps a Mac, the Mac is not showing a code yet.** The QR only exists once somebody chooses
*Pair a device…* in the menu bar, and a viewfinder opening onto a desktop with nothing on it is a
screen that says nothing while asking for the one thing that has not been done.

So the entry screen's real job is the one sentence in the whole flow that concerns the other
machine — *open Granita in your Mac's menu bar and choose "Pair a device"* — and there is nowhere
else to put it. The two credentials are full-width buttons beneath it, same width, same weight,
50pt each, camera first.

**No "or enter a code" link.** A link under a button is a confession that one of the two is for
people who failed, and the six words are not that: they are the path for a reader whose camera and
whose Mac are the same screen, which is a geometry rather than a mistake.

> Rejected: opening the camera immediately, for the reason above. Rejected: ordering the words
> first. Davide's Screens case is real and recurring, but it recurs *for him* — one reader, on the
> two devices that make a camera impossible — and taxing the ordinary pair to spare the unusual one
> is the wrong trade when the unusual one is already one tap away at equal size. If TestFlight says
> otherwise the fix is not a reorder, it is remembering which credential this phone used last.

*Should feel like* the Apple TV remote pairing screen. It does not ask you to choose a method; it
tells you what to do on the other machine, and then waits without hurrying you.

### A refused camera is a preference, so it is not treated as a fault

Two states, and the first is the one usually left undrawn: **the screen the permission alert lands
on.** The reader reads it while deciding, so it holds the viewfinder symbol, one line — *"Waiting
for camera access."* — and, already, the six-words button. Whichever way they answer, the answer was
behind the alert. The alert's own text is `NSCameraUsageDescription`, which is copy we write and the
one string in this flow that has to earn a tap: it names what is read and says nothing is
photographed or stored.

When the camera is refused, **the primary action is *Enter the Six Words*** and the description does
not mention Settings at all — *"You do not need it."* Nothing has gone wrong. *Turn the Camera On in
Settings* drops to a plain button underneath, named for what it does rather than where it goes: it
stays because a reader who declined by reflex should be able to change their mind in one tap, and it
is demoted because leaving the app to fix a state with an in-app remedy is the wrong first
suggestion.

> Rejected: an unavailable-content view whose only action opens Settings — the shape this state
> usually ships in, and a dead end that happens to have a button. Rejected: pre-flighting the
> permission on the entry screen, which asks for a capability the reader may never use and burns the
> one prompt iOS gives you at the moment it is least explicable.

*Should feel like* being offered the stairs when the lift is out — not being told the lift is out.

### The viewfinder is pushed, and it is the only dark screen in the app

Four screens, one spine: *Macs → this Mac → Scan or Words → the outcome*. Pushing puts the scanner
and the six-word field at the same depth, so moving between them is a back tap and a second tap and
no state is ever behind another state.

**The navigation bar stays over the camera.** It is translucent, it is where the reader looks to
confirm *which* Mac they are pointing at, and once the preview fills the screen the title is the
only place that fact appears.

> Rejected: a sheet. A detent is for content consulted while the screen underneath still matters,
> and here it does not; worse, a sheet can be dragged away mid-spend, and on the six-word screen a
> keyboard and a detent argue about the same 300pt. Rejected: `fullScreenCover` — it buys 96pt of
> camera and costs the Mac's name in a title bar and a success that pushes rather than
> dismisses-then-pushes.

**Dark, and the camera decides that rather than the app.** This is the one screen in Granita that is
dark in light mode, and only on the phone — see §5.5 for why the iPad is not.

**A QR that is not ours is a line, not an interruption.** An alert would stop the camera and demand
a tap for something that recurs every time the phone drifts over a sticker on a laptop lid. So the
hint under the reticle is replaced for two seconds by a capsule — *"That is not a Granita pairing
code."* — throttled to one appearance every two seconds, and the scanner never stops. It does not
say *which* code it found: nothing on this phone should read a stranger's QR back to them.

**Finding one freezes the frame.** The session stops, the preview dims, and the back button is
disabled until the outcome lands: a code that works once must not be abandonable halfway by an edge
swipe, and the frozen frame is also the only acknowledgement the reader gets that the phone saw
anything at all. This is the one place in the app a `ProgressView` is right — unlike a Bonjour
browse, this request finishes.

*Should feel like* the Wi-Fi QR scanner in Camera. You point, it recognises, and the recognition is
the whole event.

### No countdown, anywhere on the phone

The link carries no mint time, so a phone-side 2:00 starts up to 120 seconds wrong — **and it is
wrong in the dangerous direction**, reading 1:47 when the true remaining is nil, with the reader
trusting it. There is also nothing to decide with the number: an expired code and one that never
existed produce the same sentence and the same remedy, so a clock cannot change what anybody does.

The Mac's countdown is different and stays: the Mac minted the code, so its timer is true, and it is
standing in front of the person.

> Rejected: deriving a countdown from the moment of the scan. That is the honest version of a
> dishonest number. What replaces it is a consequence rather than a clock — after a refusal the
> words screen keeps what was typed and says the code is stale, which is the same information
> arriving when it is actionable.

### One field, and an echo in the Mac's own format

A single text field, monospaced at body size to match the Mac's 13pt mono, autocapitalisation off,
autocorrection off, **smart dashes off**, focused on appear, `submitLabel(.go)`. Beneath it two
lines that do the actual work: the words the phone recognised, joined by middle dots exactly as the
Mac joins them, and a count.

That echo is the whole idea. The reader's eye then compares the phone's line against the Mac's line
character for character, which is a different and far easier task than proofreading their own
typing.

**The field corrects nothing.** The server lowercases and accepts spaces, hyphens and middle dots,
so there is nothing to fix, and the capitalised first word everyone types is a keystroke the
normaliser eats rather than an error to catch. Two of those settings matter more than they look:
autocorrect will happily turn a word from a 128-word list into an English word that is not in it,
and **smart punctuation turns a typed hyphen into an en dash** — which the normaliser did not
accept, so it now does, on both ends, because the reader can also paste.

**Six words entered lights the button and nothing else.** No word count in the label, no "ready"
badge: the button turning blue is the whole announcement.

> Rejected: six auto-advancing boxes. It is the shape copied from SMS codes and it is wrong twice —
> it is not a stock control, so it would be the one hand-built thing in the app, and it turns a
> phrase into a form when the words are variable-length and paste has to land in one place.
> Rejected: a suggestion bar autocompleting from the 128 words. It leaks nothing, since the list is
> public, but it fills in words the reader never read, and a phrase they did not verify is a phrase
> they cannot correct.

*Should feel like* reading a phone number back to somebody. You say it, they repeat it, and the
repeating is what makes it safe.

### One outcome screen, and a button only where the phone can act

A spent credential has one destination and five appearances of it. **Three carry no action, and that
is precisely what makes the other two believable.**

| Outcome | Action | Why |
|---|---|---|
| The Mac is behind | none | Nothing on the phone helps. The fix is on the other machine |
| The phone is behind | *Open TestFlight*, **when the device has it** | It leaves the app, so it only appears when the URL can be opened |
| Rate limited | none | Waiting is the whole remedy. No countdown and no diagnostic |
| Unreachable | *Try Again* | Re-runs the health probe and the spend |
| Paired, key not saved | *Try Again* | Retries the Keychain write alone — see below |
| A step never answered | depends on whether the code was spent | The thirteenth state — see below |

**Both contract states say "the code was not used".** The handshake reads `/v1/health` before it
spends anything, so that sentence is true, and the reader cannot learn it anywhere else — it is the
difference between walking back to the Mac and simply tapping again. It appears twice in the app and
nowhere else.

**Success has no screen.** A `.success` notification haptic, and the stack replaces the pairing
screens with the worktree list titled by the Mac's name. Silence reads as nothing having happened
only when the destination resembles the origin, and here a frozen viewfinder becomes a populated
list, which is the loudest thing that has ever happened in this app. **The replacement is
load-bearing**: back must return to the Mac list, never to a scanner holding a spent code.

**Why the Keychain failure earns its own screen.** Every other failure says *try again here*; this
one has to state a fact no other screen states — the Mac now believes this iPhone is paired — or the
advice that follows sounds like superstition. It does not offer *Pair Again*, which would leave a
second device record beside the orphan.

**It does get a button, and that is a departure from the frame.** The review drew it without one
because it could not tell whether the token survives a failed write. It does: the outcome carries
it, so *Try Again* retries the write alone, and the trip to the Mac drops to the second sentence.
`errSecInteractionNotAllowed` is transient far more often than not. Davide's call, 25 August 2026,
against the drawn version.

> Rejected: alerts for any of these. An alert dismisses to a live viewfinder that immediately
> re-reads the same dead QR, which is a loop. Rejected: a *Contact support* or bug-report action —
> the reader is the developer, and the selectable `OSStatus` is the whole bug report.

### §5.7 — The thirteenth state: a step that never answered

**Added after the round, because a real iPhone found the one ending the review could not have
drawn.** Every state above is something that *happened*; this is the one where nothing did. Until
0.1.0 the sequence had no bound under it, so a step that took the call and never came back left the
screen drawing the state before it — which is the in-flight frame — for as long as the reader was
willing to look at it. Davide's call, 25 August 2026: *something stuck without an outcome is
unacceptable; if there is an error, we must show it.*

It is not one screen with a variable in it. **It is three, and what separates them is whether the
code left the phone**, because that is the only fact the reader can act on:

| Where it stopped | Says | Action |
|---|---|---|
| Reading the contract | *The code was not used, so trying again costs nothing* | *Try Again* |
| Spending the code | *Granita cannot tell whether it was used* — then the trip to Settings ▸ Devices | none |
| Writing the key | *…now lists this iPhone, and the Keychain took the key without ever saying whether it kept it* | *Try Again*, the write alone |

The first borrows the sentence the two contract states already carry, and it is the third and last
place in the app that says the code was not used. **The middle one is the dangerous one and gets no
button at all**: the phone cannot learn whether the Mac took the code, so a retry would be offering
to spend a credential that may already be gone, and the sentence has to be as careful as the
Keychain one — it sends the reader to remove the device record that may be sitting there. The third
keeps its retry for the reason a *refused* write does: the token survives in the outcome, and the
code that bought it is spent either way.

No new visual language: the same unavailable-content view, our sentence in the description, and the
machine's own words in caption2 monospaced tertiary underneath. The small print names the step and
says it was given the whole of its patience, which is the only part of a stall anybody can act on.

> Rejected: one sentence covering all three, on the argument that a reader does not care which
> function stopped. They do not — but they care very much whether they now have to walk to the Mac,
> and that is the same distinction. Rejected: a countdown while the bound runs, for the reason §5
> rejects every other countdown on this phone.

**The bound never fires in practice, and that is the point of it.** Seventy-five seconds sits above
the transport's own sixty-second request timeout, so an ordinary bad network still produces
*Could not reach your Mac* with `URLSession`'s own words under it rather than this. What it catches
is the step with no deadline of its own. See [`decisions.md`](decisions.md).

*Should feel like* a receipt. It tells you what happened, whether it cost you anything, and the one
thing left to do.

### iPad: 420pt, camera included

The clamp holds, and it holds for the viewfinder. The preview is a 420pt-wide 4:3 rounded card
inside the measure, on the ordinary grouped background — **the iPad scanner does not go dark.** Dark
is right on the phone because the camera fills the screen and the app disappears behind it; on iPad
the camera is one element among several, and blacking out 1194pt to host a 420pt card makes a modal
out of a pushed screen.

Detection does not suffer: the metadata output reads the whole capture frame rather than the
preview, so a smaller preview costs aim and nothing else — and aim is easier at arm's length on a
stand than with the whole slab raised. Nobody lifts an 11-inch iPad to point it at a Mac.

The six-word screen needs no iPad drawing of its own: the same measure, the field at the top, the
keyboard taking the bottom third. It is also the path most iPad readers will take, because an iPad
on a stand beside a Mac is exactly the geometry that makes scanning tedious.

> Rejected: a full-bleed iPad viewfinder with the controls floating over it. It is the phone layout
> scaled onto a surface nobody holds that way, and it breaks the rule every pre-pairing screen
> shares — everything before a paired Mac lives in a 420pt column, title included.

*Should feel like* the same screen you used on the phone, sitting still in a bigger room.

### §5.6 — The six words carry no key, and the screen says so

**This is the finding of the round, and it is the only place in the flow where a screen cannot carry
the difference.** The QR carries the fingerprint over a channel nobody on the network can write
to — the Mac's own screen. The six words carry a code and nothing else; the host and port they
borrow come from a Bonjour record any device on the LAN can publish. So the two credentials redeem
the same pairing and **are not peers**, and no amount of layout makes them so.

The words path therefore pins on first contact: whoever answers for `MacBook-Pro.local` at that
moment becomes the pinned Mac. The QR path has no such window, which is the whole reason `spki=` is
in the link.

The design carries the asymmetry in two cheap places rather than one expensive one:

1. **The camera is ordered above the words**, which is the real argument for that order.
2. **One caption at the bottom of the six-word screen** — caption2, tertiary, no icon and no box:
   *"The QR code also carries your Mac's key. Typed words trust the Mac that answers, so use them on
   a network you trust."* That is a true sentence about a pin, not a revival of the plaintext
   warning 0.0.7 retired — the connection is TLS either way.

> **Not recommended: putting the fingerprint in the Bonjour TXT record.** It would look like a fix
> and is not one. A TXT record is in-band: an impostor advertises its own key beside its own host
> and the phone pins exactly what the attacker chose. One field, two features, and only one of them
> real. The instance identifier the discovery list needs may still ride there; the key may not.
>
> Rejected: a fingerprint comparison — the Mac shows four characters of the key, the phone shows
> what it saw, the reader confirms. It is the SSH ceremony, it is buildable, and it does not ship:
> it puts a security decision in front of the one reader already pushed onto the harder path, at the
> moment they are squinting across a room. **A check nobody performs is worse than an honest
> sentence, because it launders the risk.**

**Whether the words path ships at all was Davide's to decide and he delegated it**; the decision, and
what it cost, is in [`decisions.md`](decisions.md).

### The seven questions the return came back with

It ended with a list rather than a conclusion, which is the shape a review should end in. Five were
answered by reading this repository, one by Davide and one by a decision recorded next door.

| | Question | Answer |
|---|---|---|
| 1 | What does the words path pin? | Trust on first use. The reasoning and what it beat are in `decisions.md` |
| 2 | Can the phone ship the 128 words? | **Yes** — they are the contract both ends spend, so they moved to `CorePairingDomain` beside the link that carries the code. The unknown-word line ships |
| 3 | Can the use case retry only the Keychain write? | **Yes**, and it does. §3.4 g gained a primary action |
| 4 | Is the limiter keyed per device or per dialled address? | **Per source IP address.** The review's premise came from the Mac round trip and the code had already moved on, so the kinder sentence is the one that ships |
| 5 | Does a TestFlight URL open reliably? | Unanswerable without a device — so the button appears **only when the system says it can open it**, which is this project's own rule rather than a guess |
| 6 | Will the token store keep a `pairedAt` date? | Not yet, and it does not matter yet: the already-paired state needs a Bonjour record the Mac does not publish, so **§3.1 b is the one frame this slice did not build** |
| 7 | Does the normaliser accept an en dash? | It did not. It does now, on both ends, and the field turns smart dashes off as well |

### Where this contradicts `SPEC.md`

Two places, both recorded in [`decisions.md`](decisions.md) as departures rather than resolved
quietly:

- **§8 asks for the six-word fallback *and* for SPKI pinning**, and the words cannot carry a pin.
  The spec contains the tension rather than settling it, which is why it went to Davide.
- **§10 asks for manual host entry as a fallback**, and there is none. The words screen is reachable
  only from a browse result, so the host and port are already in hand — and a field that lets a
  reader point this app at an address Bonjour never returned is a hole, not a fallback. §0 lists
  Bonjour-plus-QR as PROPOSED rather than locked, so this is the weakest of the departures here.

## §6 — Deleting a worktree *(asked for 28 August 2026, not drawn)*

Everything behind this screen is built and asserted; **the screen itself is what is waiting**, which
is the `design-handoff` rule working rather than a slice abandoned. What exists: the git command and
its eight measured behaviours, the route with its two predicted refusals, a new wire code the phone
branches on, the row's own rule about which worktrees may offer the control at all, and the model's
whole confirmation flow. What does not: the affordance on the row, and the confirmation.

**What the deletion is, so the drawing is not about a safer operation than the real one.** It is
`git worktree remove --force`: the directory goes and the uncommitted work in it goes with it. The
unforced form refuses whenever anything is uncommitted, and *every worktree this list shows* has
uncommitted work — the quiet ones are hidden by default and the product exists to show the loud
ones. So the confirmation is not ceremony around a reversible operation; it is the whole safeguard,
and there is no undo behind it. The branch survives. Nothing else does.

**Two rows must never offer it, and the row already knows which.** The primary checkout is the
repository rather than a checkout of it, and a locked worktree is a person at that Mac saying do not
remove this. `WorktreeListRow` carries a reason rather than a boolean precisely so the drawing can
choose between **absent** and **disabled and says why** — a boolean would have decided that here, by
accident, and the wrong way round.

**The open questions this section exists to answer**, and none of them is settled:

- The trailing swipe already holds Pin and Rename. A destructive third at 390pt is the question, and
  a leading-edge swipe, a context menu and a row in the rename sheet are all alternatives.
- Whether a full swipe may trigger it at all. iOS gives the first trailing action the full swipe by
  default, and a full swipe that destroys a worktree is one gesture from a scroll.
- What the confirmation is: `confirmationDialog`, `alert`, or the sheet idiom §2 already uses for
  renaming. And what it *says* — the row's stats are handed to it so it can name the cost, and
  whether it should is a call rather than an obligation.
- What the list does afterwards. The row is dropped only once the Mac confirms, so there is a moment
  with a request in flight and the row still on screen.
- Whether the two refusals get a screen of their own or share §2's existing write-failure treatment.

The prompt is [issue #52](https://github.com/fardavide/granita/issues/52), written on 28 August 2026
and **not yet sent** — Davide's credits reset first. It goes out against the baselines this
treatment records rather than against the ones that predate it, because those are now what the app
looks like.

### The provisional treatment, and every call it made without authority

**Shipped on 28 August 2026 at Davide's instruction, so the feature is usable while the review is
outstanding.** That is a deliberate departure from the `design-handoff` rule — *no pull request
touching a screen opens before its frames exist* — taken with the reason recorded rather than by
forgetting the rule. Each item below is **one file or one modifier to replace**, and a returned
design overrules any of them without argument.

1. **The affordance is a `.contextMenu`, not a third swipe action.** The swipe is left exactly as
   shipped and its full swipe still means Pin, which is reversible in one tap. This answers the
   second open question *structurally* — deletion is not in the swipe, so a full swipe cannot reach
   it — at the price of a gesture nobody can see. **Discoverability is the whole cost and it is
   real.**
2. **The confirmation is an `alert`.** Centred, not dismissible by tapping outside, bold Cancel, and
   the display name in full and untruncated as the title, because the mistake it defends against is
   destroying the *wrong* row. The competing argument — that an action sheet puts Cancel in the
   thumb zone — is genuine and was overruled.
3. **It names the cost, in three sentences branched on the row's stats.** §6 called that a call
   rather than an obligation; this makes it an obligation.
4. **`noCommitsYet` gets no "the branch stays" sentence**, because an unborn head has no commits for
   a branch to keep.
5. **The `noChanges` message claims the ignored files go too — reasoned from what
   `worktree remove --force` does to a directory, not measured.** Nobody ran it against a worktree
   holding a `.env`.
6. **The two undeletable rows are "disabled and says why" rather than absent**, and the reason is in
   the menu, never on the row. A menu is drawn over the window, so the sentence costs none of the
   320pt §2's drop order has already spent — no new drop rule, no Dynamic Type re-measurement.
7. **§2's stated reason for `locked` earning nothing has expired, and this deliberately does not act
   on it.** The document says *"v1 cannot prune worktrees, which is the only operation it would
   block."* v1 can now, so the premise is void and the conclusion is unargued. Spending the row's
   budget is not implementation's to do. **Design should be told the premise moved.**
8. **The Mac's own refusal sentence is dropped on the floor.** An alert has no caption2, monospaced,
   tertiary slot, and this design's rule is that a machine's words go there — so pasting git's
   standard error into an alert body on a phone was refused. The cost is that the reader is not told
   which of the two refusals it was, deliberately: the row said this one was deletable and the Mac
   disagreed, which means the list is out of date, and certainty would be invented at the worst
   moment.
9. **The in-flight row says `Deleting…` and loses its second line for the duration** — which in flat
   mode is the project name, the one field §2 says the list cannot lose. It lasts about a second and
   the name directly above it does not move.
10. **Dimming is used, against §2's rejection of it.** §2 rejected dimming a row that *works*; this
    row is genuinely `.disabled(true)`, so the dim is true rather than a lie.
11. **The refusal alert grew from one message to three, and `WorktreeWriteRefusal` was bought to
    route them.** If Design decides one message is enough, **delete that type** rather than keeping
    it.
12. **The cost sentences use plain interpolation, so the alert reads `+1204` where the row reads
    `+1,204`.** `WorktreeAge.label`'s precedent and its reason: a format style reaches a locale and
    these strings are asserted by a host test. Visible only above 999.
13. **The iPad's detail column is left unanswered.** Delete the worktree currently open in it and
    the pushed diff screen survives, showing a change set for a directory that is gone. Stale
    content rather than a dead control, and only on iPad, where both columns are visible at once.
    Closing it means binding the detail column's path in the split screen, which is beyond a
    provisional treatment — **and it should not ship unanswered past this review.**

**What no baseline can reach, whatever the treatment.** A `.contextMenu`'s content closure is not
evaluated until it opens, so the delete item and the two disabled explanations have no picture; and
the snapshot layouts are four device-and-appearance pairs with **no Dynamic Type axis at all**, so
§2's "Large and xxLarge both" is unassertable in this repository under any design. Both are a device
afternoon, not a check.
