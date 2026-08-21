# Design

The client's four screens, judged and drawn. This is the authority on **what the phone and the iPad
look like and why**; [`design/granita-design-review.html`](design/granita-design-review.html) is the
same review as drawings, and is worth opening for anything in §2–§4, which are screens that do not
exist yet and whose frames carry measurements this prose only summarises.

Reviewed against 0.0.4 on 21 August 2026, at iPhone 13 Pro 390 × 844pt and iPad Pro 11″ landscape
1194 × 834pt, at Dynamic Type Large and xxLarge.

Everything here stays inside the system idiom: semantic colours, SF Symbols, stock controls. Where a
control is wrong the review names the right one. Where the specification cannot be drawn at 390pt it
says so and shows the measurement.

## What is settled, and what is still open

| Section | Screen | Milestone | State |
|---|---|---|---|
| §1 | Server discovery | built | **applied** — the code matches this document |
| §2 | The worktree sidebar | M4 | drawn, not built |
| §3 | The file selector | M5 | drawn, not built |
| §4 | The continuous diff | M5 | drawn, not built |

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

## §3 — The file selector *(M5, drawn)*

### Keep the sheet. Make it a drawer, not a modal.

The selector earns its screen, but not as a modal. Enable background interaction up through the
medium detent and drop the dimming. The diff keeps scrolling behind the sheet, tapping a file jumps
the scroll *with the list still open*, and the reader walks a change set file by file without a
dismiss-present cycle between each one. That is a materially different tool from the modal version,
and it is one modifier.

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

## §4 — The continuous diff *(M5, drawn)*

### The file header sticks, and costs 28pt — but only if the toolbar goes

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

### One gutter column on the phone. Both on iPad.

SF Mono at 11pt advances 6.6pt per character. A four-digit number is 26.4pt; with 9pt of trailing
space and 4pt of leading inset, one column is 39pt and two are 78pt. At 390pt with a 12pt trailing
inset that is **51 characters of code with one column and 41 with two**. Neither reaches 80, which is
the honest headline of the section — but 41 is not a diff viewer, it is a keyhole.

**Keep the new number.** The reader is reading the current state of the file and will go looking for
line *N* in the working copy; the old number is only useful for talking to someone about the previous
state, which v1 cannot do — there are no comments and no export. On a deletion row the column is
blank, and the row tint already says which side it is. Width is computed per file from that file's
own maximum line number, so a 200-line file gets a 3-digit gutter and 8 more characters of code.

> Rejected: a single interleaved column showing whichever number exists — it looks like one sequence
> and is two, so scanning it produces wrong line numbers with total confidence. Rejected: shrinking to
> 10pt to fit two columns — 57 characters, and code you have to squint at.

### In dark mode the word segment is carried by the text

"Stronger" is a ratio, not a colour. Row tint at 10% of the semantic green or red; segment at 28%.
Below about 3× the segment stops being a second layer and becomes a slightly damp patch — and in dark
mode, where the base tint sits at 16% just to be visible against black, there is no headroom above
it.

**So invert the emphasis there.** Unchanged runs on a changed line drop to secondary; the changed run
goes to full-strength label. The eye finds the bright text, not the darker box. It works in light
too, and it is the only treatment that survives the colourblind palette, where orange on white is
already low-contrast.

> Rejected: underlining the changed run — it collides with the syntax highlighter and disappears under
> a descender. Rejected: bold — SF Mono keeps its advance when bold, so it is technically safe, but
> bold already means "keyword" to anyone who reads code.

### A collapsed bar must say why it is shut

44pt, and four things: status letter, head-truncated path, stats, and — the one the specification does
not name — **the reason**. "viewed 4 minutes ago", "1,558 lines · Load diff", "binary · no diff to
show", "renamed from … · no content change". Without the reason the reader has to open a file to
learn there was nothing in it, which is the exact cost collapsing was supposed to save.

A binary file and a rename with no content change get **no chevron at all**. There is nothing behind
them, and a disclosure control that discloses nothing is the smallest possible lie.

### Expansion lives on the trailing edge of the hunk header

The hunk header is already a full-width band carrying git's section heading — the most useful free
string in the whole diff, and the reason the header does not read as content. Put the expand control
at its trailing edge in a 44pt hit area. Not the leading edge: that is the gutter's column, and a
glyph there reads as a line number. "Expand all" goes in the file header's menu, not on screen.

**Conflict markers get the orange row and the file gets a badge.** They arrive as ordinary diff lines,
so the parser's conflict-marker kind is the only thing that makes them findable — a full-width warning
tint, the marker text at semibold, and a CONFLICTED badge in the file header so the reader knows
before they scroll. This is the one status worth a badge.

### Viewed is tapped, never inferred

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
