# Status

Where the project is. Update this when a slice lands.

**Version 0.7.0 — inline comments, and the design came back before any of the screen was built.**
Davide asked for them on 3 September 2026 — a note on a run of changed lines, a button once there are
any, one prompt for an overall note or a *Skip*, and the whole review copied out as one piece of text
for the agent that wrote the code. `SPEC.md` §11 lists that as v2 under *build none of them*, so the
departure is recorded rather than quietly taken. The round trip returned the same day and everything
it drew is built: [`decisions.md`](decisions.md) carries the calls, [`design.md`](design.md) §7 the
frames.

**Its headline is one structural decision and every other one follows from it: nothing opens in the
diff.** No row grows, no file re-lays out, no sheet pushes the scroll up. A comment is 3pt of colour
in the gutter's leading inset — the four points no figure ever reaches — and a sheet at the bottom of
the screen. That is what lets a feature GitHub builds entirely out of reflow live inside `SPEC.md`
§10's no-reflow rule without touching it.

**The gutter became a coordinate rather than a column of controls, and that is a departure with
Davide's sentence still owing.** A code row is 18pt at the smallest size a reader can choose, and
`SPEC.md` treats a sub-44pt control as a defect with no exception. §7's answer is that the minimum
governs *discrete* targets — things with a boundary you must land inside, where a miss produces
nothing — and that one recogniser over the whole 38-to-57pt strip is not one: no boundaries, no dead
space, no way to fail, and a miss that can only land one row off. It ships as drawn and is flagged;
if he declines the exception, `GutterTarget` and the two gestures come out.

**Two of §4's stated numbers were wrong and the code was right.** The gutter is quoted there as 39pt
and the code origin as 48 as though both were constants; `DiffGutter.columnWidth` sizes the figures
per file, so 39.4 is the four-figure case and the origin is 57.4 there and 50.8 on three figures. The
design read the code rather than the document and its arithmetic matches to a tenth of a point.

**The export reversed two days after it was written.** It was Markdown — headings and a fenced `diff`
block — on the reasoning that it was going into a chat. §7 overturned it: the destination is a
terminal on the Mac the phone is lying beside, the audience is an agent rather than a renderer, and
heading syntax is something that has to be stripped before it can be acted on. The excerpt lost its
`+`/`−` markers with it, because `+ func awaitItem()` is a string that appears in no file.

**One line of the document is ours rather than the design's**, and it is the case its own example
could not surface: a run named on the old side says so, because those lines exist nowhere in the
working copy and an agent opening the file at those numbers reads whatever now does.

**Three things are built differently from the frames and one they drew is deliberately absent.** The
iPad's review column is 320pt rather than 360, because 360 narrows the code pane by 40 and every
measured row height is cached on its width; the composer's anchor is a 44pt label rather than the
`Menu` §7 draws, because the extend and shrink operations behind it are not built and a menu with no
items is this project's dead control; the store's `save` does not gain a refusal, because it would be
a branch no test here can drive for a state the design itself says not to build. What is absent is
the composer's refusal screen, which §7 verified is unreachable while the diff loads once.

**Where the review lives is still deliberately not where it belongs.** The phone's user defaults,
keyed per worktree. The Mac is the right home and it is a wire change:
[#64](https://github.com/fardavide/granita/issues/64).

**A test found the rule this feature turns on written backwards.** The anchor is a row's
`(oldNumber, newNumber)` pair, which is the one address that survives both a hunk expansion and the
screen re-appearing — and the first version said conflict markers carry neither number. They carry
both sides' worth: a conflicted working tree holds `<<<<<<< HEAD` as literal content, so git diffs it
behind a `+` and the parser numbers it from that prefix *before* re-tagging it by its text, which
leaves `occupiesOldSide`'s own `.conflictMarker` arm unreachable. The genuinely numberless row is
`\ No newline at end of file`, and it is the one row a selection can span and never end on.

**A second test found the anchor was not yet an identity.** A reader who holds row 14 and taps row 11
picks the same run as one who holds 11 and taps 14, and the ends were being stored in the order the
thumb touched them — so one run filed as two comments, and the *second tap on a commented run is an
edit* rule silently stopped holding. It cannot be fixed by comparing numbers: a deletion carries only
an old number and an addition only a new one, so for that pair no arithmetic says which is drawn
first. `CommentSelection.ends(of:from:to:)` asks the diff.

**What no test kind here can answer is whether the aim works.** A snapshot renders a gutter and never
touches it, so *does a tap on 18pt of strip open the composer on the row the reader meant* is a
question for a thumb. It is the whole feature's premise and it is on the device afternoon's list,
first.

**Version 0.6.1 — five of 0.6.0's answers were right in the prose and wrong on the glass**, which is
the release the same review's photographs would have caught if the review had been run against them.
Davide read 0.6.0 on the device and sent five: files with no gap between them, a grey band in the
wrong colours, an open header and a shut bar drawing two different columns, empty grey bands under
small files, and a file list whose rows gave nothing back when pressed.

Four of the five were *built and invisible* rather than missing. §4's 10pt separation was there and
was the same white as the rows either side of it — the files now sit as cards on a grouped page. The
hunk band was drawn with `.background(.quaternary)`, which resolves the quaternary **label** rather
than the quaternary **fill** its own prose named, so a strip standing for skipped lines was the
loudest thing on the screen; it is `quaternarySystemFill` with a hairline at each edge now. The
header and the bar disagreed by a few points because `chevron.down` and `chevron.right` do not
measure the same and the two rows spaced themselves differently — one stated slot and one stated
spacing, both on the header, read by the bar. And §3's drawer now drops back to the medium detent
when a file is chosen, because background interaction is only enabled *up through* medium: a tap at
full height was jumping a scroll nobody could see.

**Then the review came back with the expander redrawn, and it replaced the band rather than restyling
it.** A bar says a control is here; a tear says something is missing here, and the second is the fact
a reader needs while reading. The row is torn on the side the content is missing from, which produces
all three forms without a rule per form — torn above at the top of a file, torn below after the last
change, torn both ways between two hunks — and a file the diff drew whole gets none at all. Three
settled calls fell to it: the glyph moved into the gutter §4 had forbidden it, the 26pt band became a
44pt row, and a row now stands for one **gap** rather than for one hunk. That last one is the
structural half: `DiffFileRow.rows(of:)` decides the whole thing in `Domain`, with a test per
placement, and `DiffFileContent` draws what it is handed. All in [`decisions.md`](decisions.md).

The fifth was half a fix and now has a boundary drawn round it. A band with no heading and no gap
either side is no longer drawn — it names nothing and opens nothing. **Davide's hunch that an arrow
was missing is also right**, and that half is the Mac's: `WorktreeService` derives a file's new-side
length from its *last hunk's* end rather than from the file, so the last hunk of every file reports
no gap below it and never offers the downward chevron. He ruled against spending the two extra `git`
invocations per file it would take — *"it is fine in case there's nothing to expand below, but we
should not show an empty expander"* — so the requirement is on the drawing and it is met. In
[`decisions.md`](decisions.md), with what it costs. **The redrawn expander raises the price of that
call**: its *remainder of file* form is exactly the state the Mac cannot report, so that form is
built, has a baseline in all four layouts, and cannot currently be reached by a real diff.

**A sixth thing came out of the coverage gate rather than out of the screen.** The rule saying which
detent means which drawer height was written as a `Binding(get:set:)` inside the sheet — two closures
no baseline renders and no host test reaches — and the Snapshot row fell for it. It is on
`ClientViewerModel` now as `drawerDetent`, the screen hands the sheet the framework's own projection,
and a unit test drives both directions. The row's usual answer for a falling number is *do not
restructure the screen*; that answer is for an action closure, and this was a decision hiding in a
binding.

**Version 0.6.0 — the diff view was reviewed against a photograph of itself, and it had a correctness
bug in it.** The gutter carried the new-side line number alone, so a *removed* line — which has no
new-side number — drew an empty column: the one row that says something was taken away was the one
row a reader could not point at. It ships now as one column carrying whichever side the row is on,
with a `+`/`−` marker beside it, and the two calls stand or fall together — the marker is what
answers §4's own reason for rejecting a single interleaved column. Long lines fade at the trailing
edge instead of stopping dead, each hunk carries a scroll indicator, rows went from 13.7pt to 18 while
the hunk band went from 43 to 26, a file says its name over its place, and the viewed control is a
44pt target that leaves a visible trail. Both reversals are in [`decisions.md`](decisions.md);
[`design.md`](design.md) §4 is rewritten around them.

**Two of the review's own calls were overruled here**, and both are recorded rather than quietly
resolved: the hunk band's expand control keeps its 44pt hit area by taking it horizontally in a 26pt
band, because the review draws a 26pt target while its own eighth fault is a target under 44pt; and
the iPad drops its second gutter column with the phone, spending the room on 12pt code instead.

**Three things in the review are recorded and not built.** The large title and its `working tree · 11
files · +105 −12` subtitle — the totals are a placeholder the review itself flags as invented, and a
change-set total is not on the wire; and the proportion bar for `+95` against `+1`, which the review
rules out of its own scope and leaves as a question for Davide.

**Versions 0.5.2 and 0.5.3 had no entry here and now have one.** Both are diff-view releases and both
were about the same defect: a layout the reader changed was snapping rather than moving. 0.5.2 put the
curve on the two halves of a file's section, which cross-faded the bar into the header while every
file below it jumped; 0.5.3 moved it to the stack that lays the movement out. The rule that came out
of it — **the animation goes on the container, never on the row** — is in [`design.md`](design.md)
§4, and nothing in the snapshot suite can see it.

**Version 0.5.1 — the iPad read its worktrees through a phone-shaped slot for four releases, and the
baseline that should have caught it had photographed the defect.** The 420pt measure design §5 puts
around the pairing screens was released only for a Mac *just paired with*, so the route a reader
takes every day — tap a Mac already paired with — opened a split view inside a 420pt column: a 320pt
sidebar, a sliver of detail, white down both sides. The container and the rule moved out of the
composition root into `PairingSpineScreen` and `PairingSpineNavigation`, where the sequence is a host
test and the width a push lands at is a baseline. In [`decisions.md`](decisions.md).

**Version 0.5.0 — a worktree can be deleted from the phone, and the screen shipped ahead of its
design on purpose.** Davide asked for that on 28 August 2026: he was near his weekly limit, wanted
the feature usable, and wanted the design round trip to correct it afterwards. So the
`design-handoff` rule was departed from with his instruction and the cost written down — the prompt
is [issue #52](https://github.com/fardavide/granita/issues/52), written *before* any of the screen
was built so the ask cannot be reconstructed from the code that guessed at it, and
[`design.md`](design.md) §6 lists **thirteen calls made without authority**, each one file or one
modifier to replace.

**The treatment was chosen by a panel and the panel found a control that did nothing.**
`confirmDeletion()` read its subject back off the model, and dismissing an alert clears that property
synchronously while the button's own `Task` body runs a turn later — so Delete destroyed nothing at
all, with the whole suite green, because a raster does not include an alert and cannot press a
button. That is this project's oldest defect arriving through a new door, caught before it shipped
rather than after eight releases. In [`decisions.md`](decisions.md).

**Deletion is deliberately not in the swipe.** A trailing swipe begins the way an imprecise vertical
scroll does and iOS gives the first trailing action the full swipe, so a destructive third action
there is one over-committed thumb from destroying work that was never committed. It is a long press;
the swipe keeps Pin and Rename and its full swipe keeps meaning Pin. That answers §6's open question
structurally rather than by tuning a flag — and costs discoverability, which is real and recorded.

**`isLocked` has a job for the first time, and §2's reason for it having none has expired.** The
document says *"v1 cannot prune worktrees, which is the only operation it would block."* v1 can now,
so the premise is void and the conclusion is unargued — but spending the row's budget is not
implementation's call, so the reason lives in the menu where it costs nothing. Design is told the
premise moved.

**Deleting a worktree was built everywhere except the screen first, and that half still holds.**
Davide asked for it on 28 August 2026, with a confirmation in front of it — which re-opens a line
`SPEC.md` §11 had drawn, since pruning worktrees is listed there in the v2 backlog and design §2
leans on that when it decides the locked flag earns no pixels. It is `worktree remove --force`, once:
the unforced form refuses whenever anything is uncommitted, which is *every* worktree this app lists,
so the confirmation is not ceremony around a safe operation but the whole safeguard. A second
`--force` would override a lock and is not sent. The branch survives. Every call in
[`decisions.md`](decisions.md), with the eight git behaviours each one was measured against.

**`isLocked` has a job for the first time.** Design §2 filed it as plumbing — *"v1 cannot prune
worktrees, which is the only operation it would block"* — and that is the operation. The row now
carries a deletability with a **reason** rather than a boolean, because a control that is absent and
a control that is disabled and says why are different answers and only the design picks between them.
A screen physically cannot offer the control on a worktree the Mac would refuse.

**What is not built is the swipe action and the dialog**, and that is the `design-handoff` rule
working rather than a slice left half-done: no pull request touching a screen opens before its frames
exist. Everything a frame cannot be authoritative about shipped — the git command, the service seam,
the route with its two predicted refusals, the wire's new `worktreeNotDeletable` code, the phone's
client, the row's rule and the model's whole confirmation flow, all asserted. The prompt for Design
is written. **There is no version bump and no changelog entry with it**, because nothing here is
something a reader can do yet, and merging publishes.

**The removal tests own a repository rather than borrowing the fixtures**, and reading its paths back
from git rather than computing them cost two red runs. An identifier is a hash of a path *string*,
and a `URL` for a directory carries a trailing separator git never emits while
`resolvingSymlinksInPath()` leaves `/var/folders` alone where git says `/private/var/folders` —
either spelling hashes to something the registry holds nothing under, so every route answers
`worktreeGone` about a worktree sitting right there.

**The changed words carry a background now, and that was the syntax highlighter asking for the text
colour back.** Design §4 had inverted the word diff into the text — unchanged runs down to secondary,
the changed run at full strength — because it measured two nested backgrounds and found no headroom
above a 16% row tint in dark mode. It reads well, and a lexer colours text, so a line already using
its colour to mean *this part changed* has nothing left to say `keyword` with. Davide settled it back
to what `SPEC.md` §10 had asked for all along. **The half of §4's argument that survived is the
ratio**: two translucent layers composite rather than add, so one fixed alpha reads as a different
multiple of the row in each appearance — which is the drift the review rejected the treatment for. So
the ratio is stated and the alpha is solved from it, the changed run landing at three times its row's
tint in both. The dark baseline is what says the treatment survives dark mode after all. In
[`decisions.md`](decisions.md).

**A tab in the middle of a changed line was drawing at the wrong column, and nothing had hit it.**
The old treatment built one `Text` per segment and expanded each segment's tabs from column zero of
that *segment*, so `if\ttrue` split after `if` drew four spaces where the grid says two — every
column after it wrong against the gutter the scroll is measured from. The expansion carries the
column between runs now, `MonospacedGrid` owns it in one place, and the property that the runs joined
equal the whole-line expansion is asserted. Reachable in any tab-indented file with a word-level pair
on a line with a tab in the middle of it.

**A file you have read shuts itself, which is what `SPEC.md` §10 has asked for since the mark
existed.** 0.3.0's toggle moved a circle and left the diff open under it; the bar is what makes the
sentence true. It goes **in the header's slot** rather than under a header — 44pt, status letter,
head-truncated path, stats and the reason — and the reason is the field design §4 added to the
specification, because without it a reader opens a file to learn there was nothing in it. Four
sentences, and a binary file or a rename that changed nothing gets **no chevron at all**, the whole
row stopping being a button with it.

**The bar for a viewed file says "viewed" and cannot say how long ago**, which is the wire rather
than a shortened sentence: the Mac stores a mark as the content hash it was set against and keeps no
time beside it. Same call as §3's truncation footer, in [`decisions.md`](decisions.md).

**A file drawn shut is not fetched, and that is what makes *Load diff* true.** The scroll steps over
every collapsed file, and opening one fetches it as a batch of one — without that half, pressing a
bar leaves a header over a blank stretch nothing ever fills, which is this project's own dead
control arriving through the door built to stop it. It also pays for itself on the ordinary screen:
in a change set you have been through once, every file you read is shut.

**Hunk expansion is spliced into the diff rather than kept beside it.** `/lines` finally has a
caller. A press produces a *wider* `Hunk` — new bounds, new counts, the context in file order — so
"is there anything left above this one" is answered by what is drawn and the control disappears the
moment the gap closes. Three things fell out of building it and each is asserted: git's `+c,0` names
the line *before* a pure deletion rather than the first line of it, the offset between the two sides
is not the same number above a hunk as below it, and every window is read from the new side.
`DisplayWidth` is public now, because the phone makes lines the parser never saw and two
implementations of one Unicode judgement is a row-count error waiting for a wrap mode.

**A baseline caught a `Divider` drawing itself sideways.** Inside a `Button`'s label it read the
bar's own `HStack` and drew vertically — a stray line down two of the four bars and no rule under
them. That is this repository's third measurement that settled itself differently in two places,
after the list margin and the scroll position, and the answer is the same: state the value.

**Both of 0.3.0's open calls are Davide's answers now, and both stand as they were.**
`NoWorktreeChosenView` stays, because design §2 asks for an unavailable-content view in the empty
detail column in as many words; `WorktreeSplitScreen`'s doubled `navigationDestination` stays
doubled, because what it settles is which container claims a tap and removing a declaration to find
out is how this app shipped a row that did nothing.

**Version 0.4.2.** Scaffold complete, CI green, `main` protected, **shipping to TestFlight** — and
merging is what publishes, so the version in `project.yml` is what this tree will put on a phone
rather than what is on one now.

**The six words have a Copy button, which finishes a sentence design §5 started.** The separator
under the QR was chosen so a reader who *selects the line and pastes it* is not refused for the
tab's own punctuation — and the tab then left them to drag a selection across six words in a 13pt
monospaced line. It is `doc.on.doc` on the same line as the words, because §5 records that the next
*line* added to that pane puts the countdown below the fold. What it copies is the line as drawn,
and `SpokenWords` now owns both the separator and the drawn spelling so the tab's choice and the
phone's tolerance are one fact with a round-trip assertion behind it. **It does not solve the
same-device case** — a reader on Screens is looking at this Mac from the phone being paired, and the
two have different clipboards. That is still the Allow path.

**Four defects found by running the product on a phone, and three of them were invisible to every
test kind here.** Davide connected an iPhone, read a diff, pressed Back and got *Could not read your
Mac* with a *Try Again* that looked dead. The Mac's log said `hashWorktreeFiles` was failing over and
over. Root cause: a **symlink pointing at a directory** in two `bandlab-android` worktrees — git
refuses to hash it and exits 128 for the whole batch, so `/v1/worktrees` could answer nothing. The
error on screen was a second defect: `NSURLErrorCancelled` folded into `unreachable`, so the app was
blaming the Mac for a read the app itself had cancelled. The dead-looking button was a third — a
retry with no feedback against an endpoint measured at 122.7 seconds. And the reason the first had to
be reproduced by hand rather than read is a fourth: the git failure log line spent its whole
kilobyte on `RepositoryRelativePath(bytes: 36 bytes)` and truncated before git's stderr. All four are
in [`decisions.md`](decisions.md).

**Two more are known, confirmed and not yet fixed**, both about a connection that should persist:
nothing joins a discovered Mac to a stored token, so selecting a paired Mac asks to pair again; and
nothing re-resolves via Bonjour before using a stored address, so a Mac that restarts on a new port
strands an already-paired phone. See "What to pick up next".

**Design §3's file selector is built, and with it the mark that is this product's whole point.**
Tapping a worktree opened one continuous scroll and no way to move around it; there is a file list
now — a drawer on the phone at the medium and large detents with the diff still scrolling behind it,
and on iPad a permanent 320pt column, which is §4's three columns at 320 / 320 / 554. The tree is
`CoreTreeDomain`'s, unchanged; what is new is the join with each file's own state, the collapse rules,
the two cases where a tree is ceremony, and the footer. **The viewed toggle landed with it rather than
after it**, because a column reporting a state nothing in the app can write is a column that is empty
forever.

**A photograph decided two things again, and one of them was a control that did nothing.** The jump
was built on a `ScrollViewReader` and `proxy.scrollTo`, which is the obvious thing and does not work:
the stack is lazy, so when the watch fires the row being scrolled to does not exist yet, and the
baseline came back with the first file still at the top. It is a `scrollPosition(id:)` over a
`scrollTargetLayout()` now, which applies during layout. **And the first fixture for it proved
nothing** — 0.2.0's three-file change set fits on one screen, so a jump that worked and a jump that
did nothing photographed identically. There is a control render beside it now, and the pair is what
makes the claim. Both in [`decisions.md`](decisions.md).

**The jump lands about 120pt short of the file's top, and the baseline says so rather than hiding
it.** Anchoring, an explicit section identity and the scroll target layout were each tried; none
closes it, so it is `scrollPosition` interacting with pinned section headers. The reader gets the file
they tapped, near the top of the screen — the last 120pt goes on the device afternoon's list.

**Four points of list margin turned out to be one character of directory.** §3's row is a
head-truncated path at the edge of what fits, and inside the iPad's split view the list's own
horizontal margin arrived at two different values for the same layout — a red suite that nothing in
the diff explains. Pinned now. That is this repository's second measurement-that-moves after the
locale trap, and it is the same lesson: what a baseline asserts has to be a fact rather than a
reading.

**Two things the slice was asked for and deliberately did not do**, both recorded and both Davide's
to settle: `NoWorktreeChosenView` stays, because design §2 requires an unavailable-content view in the
empty detail column and the composition that shipped still has one; and the split screen's doubled
`navigationDestination` stays doubled, because which container claims a tap cannot be settled here and
removing a declaration to find out is how this app shipped a row that did nothing. See "Waiting on
Davide".

**The diffs are on the phone, which is the thing this product is for.** Tapping a worktree opened a
screen saying the file list was not built; it opens design §4's one continuous scroll now — every
changed file in one lazy stack with pinned headers, wrap off, the line numbers pinned while the code
runs off the trailing edge. `WorktreeNotReadyView` is gone, the way `PairingNotReadyView` went in
0.1.0.

**§4's wrap-off row is two view trees, and a photograph is what said so.** The first build put the
numbers and the code in one view with the code at `fixedSize`, and the baseline came back with the
gutter pushed off the leading edge: a row wider than its container is centred in it. SPEC §10 pins
the gutter *while the code scrolls*, so the numbers are a fixed column outside the scroll and the
code a stack inside it — which means two stacks have to agree on every row's height, so the height is
taken from the font and stated once rather than left to two text engines. The row and its five
baselines came back out and were rebuilt in the right shape. In `decisions.md`.

**The file header ships in one form where §4 draws two**, and that is the no-reflow rule again: a
pinned section header keeps its slot while a copy floats, so a header that is shorter when pinned
changes the height of a slot *above* the viewport and moves everything under it. It ships as the
pinned form, losing the second line, which §4 itself calls orientation for arriving rather than for
staying. **Provisional** — whether a two-form header can hold one slot height is a question for a
real scroll under a real thumb.

**The forward-only rule is a pure function with its own suite.** `ContinuousDiffLoading` never
fetches a file the reader has scrolled past: filling a gap above the viewport turns a placeholder
into real content and moves the screen they are reading, which is the defect SPEC §10 exists to
prevent. Files load five ahead, in one `/diffs` request, and a refused batch leaves placeholders
rather than replacing a screen the reader was already using.

**What no test kind here can answer is whether it feels right.** A two-axis scroll inside a vertical
one that must never reflow is the hardest gesture in this product, and design §4 says to build it
first for exactly that reason. It is built; it needs a thumb.

**The pairing design came back on 25 August 2026 and is now built.** Four
screens, twelve states, and a finding no frame could carry: **the six words carry no key.** The QR
carries the fingerprint over a channel nobody on the network can write to; the words carry a code,
and the host and port they borrow come from a Bonjour record any device on the LAN can publish. The
client had already settled that in the strictest direction by accident — `PairingLink(url:)` throws
without an `spki` and the pinned transport cannot build a session without one — so on 0.0.19 the
six-word screen could not have been built whatever it looked like. `SPEC.md` §8 asks for the pin
*and* for the fallback, so the spec contains the tension rather than settling it; Davide delegated
it, and **the answer is trust on first use**, carried by ordering the camera first and by one
caption2 line that says what the difference is. Every call, and the five other questions the return
came back with, are in [`design.md`](design.md) §5 and [`decisions.md`](decisions.md).

**The slice landed foundation first and screens second.** `SpokenWords` moved to
`CorePairingDomain` — the list is contract, both ends spend a credential against it, and the phone
needs it to say *"branch" is not one of the words* before a round trip that costs a fifth of the
rate limit. The normaliser now accepts an en and an em dash, because iOS smart punctuation types one
whether or not anyone meant to and **paste is the path no field setting reaches**. Then the camera,
the Bonjour endpoint resolution the words path needs, the model behind all four screens, the four
screens themselves, the spine that joins them, and the iPad's split view. 786 tests.

**Then an adversarial read of that slice found six defects, and five of them were invisible to every
test kind here.** One model serves the whole app and had no notion of an attempt ending, so *Try
Again* could spend one Mac's QR code while the screen was titled another's, the viewfinder re-opened
on the frozen frame of a spend that had finished, and a second Mac's six-word screen arrived with
the first Mac's phrase already typed. An IPv6 address — bracketed by nobody, its zone escaped by
nobody — produced a `file://` base URL on **both** the pairing route and every read route, so a Mac
reached over v6 was reported unreachable twice for reasons a reader would have read as one. A
newline fused two words, which broke the paste that §5 makes the answer for the same-device case,
and the Go key over that field could never have submitted anything. The iPad opened every worktree
on a screen titled *This worktree*, because the composition root rebuilds the model on every
evaluation and only the sidebar had pinned one. All six are in
[`decisions.md`](decisions.md); the IPv6 entry there **replaces one that recorded the defect and
argued for leaving it**, and was wrong about how much of the app it reached.

**The iPad has its two columns, and getting them cost two broken renders.** §2's 320pt sidebar and
its *Choose a worktree* detail column waited for a composition root that presents this screen, and
pairing brought one. A split view that folds in a compact width draws no content at all when it is
inside a navigation stack, so the phone branches to the sidebar directly; and a split view keeps the
destinations declared inside its columns, so the rows — value-based links whose destination has
lived beside them since §2 shipped — stopped reaching anything, which is this project's oldest
defect arriving through the door built to stop it. Both were found by a photograph rather than by
reading, both are in [`decisions.md`](decisions.md), and the row's destination is now declared on
each container that can claim a tap. The root's 420pt measure stops at the paired Mac, which is
where §5's column and §2's sidebar meet.

**Tapping a Mac now leads somewhere, and so does pairing with one.** The spine is *Macs → this Mac →
Scan or Words → the outcome*, pushed on a path the composition root holds, and a pairing that works
**replaces** the pairing screens with that Mac's worktree list rather than pushing a fifth screen —
so back returns to the Mac list and never to a viewfinder holding a spent code. Success is a
`.success` haptic and that replacement, which is the whole of it. `PairingNotReadyView`, which said
for one release that pairing had no screen, is gone.

**One thing the return assumed that this repository did not have, and 0.4.1 supplied differently.**
Nothing joined a discovered Mac to a stored token, which was read as waiting on the TXT record SPEC
§8 asks for. It was waiting on the **key** instead: a pairing is now filed under the Bonjour instance
name, which a browse result carries, so a Mac paired with before opens its worktrees on the first tap
and the pairing screens are reached only by a Mac this phone does not know. §5's already-paired
*screen* stays unbuilt on purpose — its frames remain in `.claude/docs/design/` for the one reader
who reaches it, whose token the Mac revoked. See [`decisions.md`](decisions.md).

**None of the pairing screens or the sidebar's controls has been pressed on a device.** Every one is
asserted at the model, but a camera, a Keychain and a QR held across a room are three things this
machine cannot produce — and the viewfinder's own preview is the one piece of this slice **no test
kind that runs here can execute a line of**. M3's acceptance and M4's are the same afternoon with a
phone in hand.

**Design §2's drawings contradicted its own prose in two places, and the prose won both.** The
rename sheet's footer previews the session summary rather than the branch, because the footer's
stated job is to say what the row will read after Save and the Mac resolves a suggestion ahead of a
branch — a footer that is wrong in the one case a reader checks it is worse than none. And a quiet
primary checkout is hidden like any other, because exempting it makes §2's own "all 9 are clean"
state unreachable. Both are Davide's calls rather than picked, and both are in `decisions.md`. §2's
frames are gone, which is that rule working: what survives a drawing is the argument.

**The first four-digit figure on a screen found the locale trap.** `+1,204` recorded as `+1.204`,
because a grouping separator is the environment's decision and this machine's simulator is not the
runner's — a baseline nothing in the diff would have explained. The snapshot helper now pins
`en_US`, which asserts one layout deliberately instead of whichever the simulator happened to be on.

**What §2 drew and M4 could not build was the iPad's split view** — the 320pt sidebar and the
*Choose a worktree* detail column, which needed a composition root that presents this screen. Built
now, above. What did **not** follow is a re-record of the sidebar's own 52 baselines: they
photograph the view and the screen across the whole iPad width, which is a width the row never has,
and the layout that ships has a subject of its own instead. Re-recording another slice's screens
inside the commit that wires navigation is a review nobody can perform.

**The Mac is finished for M3.** All five Settings tabs, the status item and its menu, TLS, Bonjour,
pairing codes, the QR, logging, and now the lock file. What is left of the milestone is its
acceptance — pairing from a real device on the LAN — which this machine cannot answer.

**Advanced grew its Diagnostics half, and the switch moves a server that has been running since
launch.** That is what the seam was for: verbosity is re-read per line, so the model writes the
setting and not a copy of it. Both positions are photographed without either costing a baseline of
its own. *Open in Console* beside it is two gestures rather than one link, because `Console.app`
registers no URL scheme — the predicate goes on the pasteboard and the window opens next to it, and
the footer says to paste, since a Console window that opens unfiltered is a button that appears to
have done nothing.

**Two Granitas can no longer both hold the document, and the second one says which one has it.**
SPEC §9's lock file, `flock` rather than a pid file whose contents decide — a crashed Granita
releases its lock because the descriptor closes, which is the case a pid file gets wrong. The
refusal is **a run state of its own** rather than a `failed` carrying a different sentence, and
that is the whole point: `failed` tells a reader to check Local Network access, which for a lock
conflict sends them to a pane that is already correct. General names the process and offers **Quit
Granita** — an `LSUIElement` app has no Dock icon and no window whose red button ends it, so without
that the instruction names something a reader cannot do from the screen giving it. Advanced reads
the same refusal, which is where design §7 puts it.

**The coverage gate runs locally, and it answers five of the six values rather than six.**
`make coverage` fetches `main`'s numbers and applies the same verdict CI applies — same script, same
predicates, same exit code — because five times a fallen row had been read from a red pull request
instead, at twenty minutes a time for a number the working tree could already produce. **`All tests`
lines is the exception, and it was read rather than estimated**: on a clean tree at 0.1.0 it comes
back 12 lines under what the runner published for that same commit, and the runner's own per-file
export names all three files — `ApiServer` by seventeen, `BonjourBrowser` and `SessionIndex` back the
other way. None of them is code a test drives; all of them run because a snapshot suite is app-hosted
and the host starts a real server and a real browser, which get different distances on a laptop than
on a runner. The 2026-08-24 verification that said "identical on all six rows" predates the Mac
suite's contribution growing that far. The `swift-testing` skill carries both halves now: what to
cover as you write it, and how to read that one row.

**Three more controls that have never been pressed**, and the count of those is now ten. See
"Waiting on Davide": the Accessibility grant is the whole of what stands between `make ui-tests-mac`
and an answer, and the failure it gives has changed to one that names a prompt rather than a
timeout.

**Granita writes a log, which until 0.0.17 it did not do anywhere at all** — not a `Logger`, not an
`os.log`, not a print, the whole package searched. Every request the server answers and every git
invocation goes to the unified log under `dev.fardavide.granita`, in two categories a reader can
filter by. **A note is never behind the switch**: a git command that could not be run and a request
that was refused are written whatever the setting, because a fault someone has to enable logging to
see is one they learn about too late. The detail is what the switch will gate, and until Advanced
grows it that is `defaults write dev.fardavide.granita granita.diagnostics.verbose -bool YES`.

**What is written is narrower than what is available**, and that is the security boundary rather than
tidiness: the git decorator logs the command and the checkout, never git's standard output, which is
a private repository's contents; the middleware logs the method and the path, never the query or the
body, because `/v1/pair` carries a live code and `?projectID=` resolves to a folder on this Mac. Both
are asserted. `os.Logger`'s default redaction is turned off, narrowly, and is safe because of exactly
that.

**Two decorators, not two dependencies.** `LoggingGitClient` wraps a `GitClient` and
`DiagnosticsMiddleware` sits on the router — so `ProcessGitClient` keeps one job, and the libgit2
client the protocol exists for would arrive logged without knowing it. The middleware is on the
router rather than the authenticated group, because the requests most worth reading about never get
that far; a test found that a refusal arrives as a thrown error rather than a 401, so it takes the
note path and survives the switch being off.

**The verbose switch and *Open in Console* are still not built, and that is now a scheduling call
rather than the recorded one.** `decisions.md` said they land with the layer; they land with the
lock-file row instead, because all three change `AdvancedSettingsView`'s eight baselines and the
window's `serving-advanced` pair, and a Mac baseline costs a full round trip. One round trip instead
of two.

**The menu bar item does things now, and all seven of the Mac's drawn surfaces are built.** The
status line is a `Button` that copies — `macbook-pro.local:59144`, with no scheme, because the
frames drew `http://` against 0.0.6 and TLS landed in 0.0.7, and `https://` pasted into a browser
under a self-signed identity produces a warning rather than an answer. It copies through the same
call General's row does, so two places cannot spell one fact two ways, and it carries General's own
`doc.on.doc` because a menu closes on click and a row whose whole effect is a changed pasteboard has
no way to report itself afterwards. *Pair a device…* opens Settings **on Devices** — one QR, two
doors — enabled while starting and disabled when the server is failed or stopped. A failed server
leads with *Not serving* and **Open Local Network Settings…**; it does **not** name the cause, because
a locked keychain reaches that state too and a menu has no room for the small print General uses to
say "likely". Three symbols rather than four: failure and stop are one answer to the one question a
menu bar asks. **The count is not built and is not owed** — 122.7 seconds.

**The pane does not ride on the settings request**, which is what `decisions.md` predicted it would
do and is now superseded there. `ServerMacModel` has owned the selection since 0.0.15, so a pane on
the request would be a second copy of it — and `SettingsOpener` watches that value with `onChange`,
which cannot tell *asked for Devices again* from *nothing happened*. Pressing the row twice with
Advanced in between would have been a dead control built by the mechanism meant to prevent one.

**Settings reopens where it was left, and on Projects the first time.** Both are one question, so the
seam answers with a pane **or nothing** and the model decides that nothing means Projects. It is user
defaults rather than the JSON document: that file is shared with `granita-server`, which has no
window, and is about to grow a lock file so the two cannot both hold it. Synchronous, alone among the
seams here, which is what makes it impossible rather than unlikely for a restore to land after the
menu asked for Devices and take it back off the screen.

**Four new controls, and none of them has been pressed.** They are photographed — the menu's rows in
a stack, because a `MenuBarExtra`'s menu is drawn by AppKit outside this process and there is nothing
to render — and a picture cannot say whether anything is behind a row. That is the Accessibility
grant's job, below.

**Devices is built, and the Settings window now has all five of its tabs.** The QR is the largest
thing in the app and it is what the 620 × 560pt window was sized from — and the first render put the
countdown below the fold, which is a measurement worth keeping: ten points of spacing between five
children was the whole difference. The six words sit under it as an equal rather than as a caption,
and the middle dot the tab draws between them is now a separator the server accepts back, because a
reader who selects that line and pastes it into a phone must not be refused for punctuation this tab
chose. Fourteen baselines across seven states, two of which the frames do not draw and both of which
had to exist: a code being made, and a code that could not be. **The plaintext warning the frames
show is not built** — 0.0.7 made it false.

**A device row says what is true and no more.** The platform and the day it paired come from the
store; *Seen 4 min ago* comes from the connection log, which is in memory, so a device this run has
not heard from says how far back the run goes rather than showing a date that reads as an accusation.
The join is on an identifier the log now carries beside the name — two phones can be called the same
thing, and a sighting on the wrong row is the kind of wrong that looks right. Following the log moved
to the composition root for the same reason: it used to start when Connections was opened.

**A refused connection now offers the thing that fixes it.** `Pair…` for no token, `Pair Again…` for
a token this Mac never issued, and nothing at all for version skew or rate limiting. Inside the
window that is a tab switch — and **which pane is up is the model's, not the window's**, because a
control whose only effect is a `@State` two layers up is a control nothing can be asked about. That
is the shape of the dead row this app shipped for eight releases, and it is also what §1 needs: the
menu's *Pair a device…* has to open Settings **on Devices**.

**The composition roots are a layer now, `Main`, and that is not a rename for tidiness.** Two of the
three were filed under `Presentation` while being neither, so the exemption they need could not be
read off a path — it was written out by hand in five places, two of them clauses inside the coverage
scope predicates that decide whether a pull request may merge. Both clauses are gone: one became a
layer name matched the way `Ui` is, and the other disappeared outright. **The rows stay judged**,
because the predicate selects exactly the files it always did. What came out of the Mac's root with
it is the part that was never wiring: a server host whose four failure sentences no test could reach,
now `TransportResolvingServerHost` beside the host it wraps and asserted line by line, and the wake
source, which turned out to be reachable by a host test after all rather than needing the exemption
it was moved out expecting.

**Projects is built, and it is the security boundary.** Nothing on this Mac is visible until a
repository is added *and* switched on, and the tab keeps those two verbs apart at every point: a
folder scan opens a sheet, its results never enter the list, there is no *Select All*, and everything
it adds arrives switched off. A project whose folder moved now says *Folder not found*, keeps its
last known path and offers **Locate…** with its switch disabled rather than quietly turned off —
until now it stayed enabled and served nothing, which on a phone reads as a repository with nothing
in it. **The trailing figure is drawn in two passes**, and that is a measurement rather than a
shortcut: the worktree count is 0.014 seconds for a whole project and the count of worktrees with
uncommitted work is 16.7 for one monorepo's sixteen, so the tab draws what it knows and fills the
rest in as it lands. Davide chose that over dropping the line. Ten baselines, and the scan follows
SPEC §9's skip list rather than the frame that shows `vendor/swift-nio`.

**The Settings screen does no I/O any more, and that was a structural fix rather than a coverage
one.** `GranitaSettingsScreen` held an `NSOpenPanel`, an `NSPasteboard` and two `NSWorkspace` calls,
excused as one-line gestures — until a folder picker joined them, and a picker *decides*. The screen
was at 45 uncovered regions of 56, and the reflex was to blame the scope. Davide refused that: Ui
must be declarative, and a state a model cannot drive is a structural issue rather than a
measurement one. `FolderPicking` answers and `SystemGestures` does not; the model gained six drivable
flows; three questions became askable and are asserted, including whether Copy puts on the pasteboard
the string the row actually shows. **Only then was the coverage predicate corrected**, and it needed
correcting for a bigger reason than models: the views scope was counting a server host and a
composition root as code a rendered baseline executes.

**Advanced is built, and it is last.** The git row runs git rather than reporting which of three
candidate paths won — that is the whole point of it, because a path that is executable and broken
looks exactly like a working one until something runs it — and in failure it carries git's own
standard error. Beside it the data folder with a Reveal, and `Reset All Data` counting what it would
destroy before it does. **Its Diagnostics half is still absent**, and the reason has changed: the
logging those two rows describe exists as of 0.0.17, so what they are waiting on is now the baseline
round trip they share with the lock-file row. All three change the same eight pictures.

**The macOS UI test target exists, is built by CI, and has never been seen to pass.** That is the
honest state rather than a half-landing: a UI test bundle is a separate runner app that must be
signed to connect at all, both test bundles need a generated plist once anything is signed, and the
last layer down is an **Accessibility grant on this machine** that no project setting can supply —
System Settings › Privacy & Security › Accessibility. `make ui-tests-mac` is the door; nothing in CI
runs it, and the report's `ui` row stays empty on purpose, because a near-zero row recorded from a
target that cannot run would become the ratchet baseline. Joining the `GranitaMac` scheme meant
scoping three invocations with `-only-testing` first, the CI snapshot job included, or that job would
have started driving the app instead of photographing it.

**The app no longer has a dead control in it.** From 0.0.4 to 0.0.11, tapping a Mac in the discovery
list did *nothing at all* — the rows were `NavigationLink`s and no module declared a destination for
them. It shipped, and a comment in the composition root said so in as many words. Tapping now opens a
screen that says Granita can find the Mac and cannot connect to it yet, and the destination lives
beside the rows that link to it rather than in the root. **The rule is stated in the files that load
unconditionally** — the global `CLAUDE.md`, this repository's, and `/design`'s binding rules — rather
than in a skill, which is only read when something reaches for it. What is still owed is the
behavioural test that would have caught it, which needs the `ui` target this project has never had.

**The connection log is a tab of its own and has been relaid out.** It was sharing Advanced with
`Reset All Data`, which is a bad place for the one panel opened under pressure. Its row drops the
word "Refused", carries the address the attempt came from and **how many times it happened** — the
coalescing was folding four hundred attempts into a row that looked like one — and a footer says how
far back the panel goes and how full it is. The `Pair…` affordance a refusal is meant to offer is
**blocked behind the Devices tab**, which is the door it opens, so §6's frames stay in the review
until then.

The reason it could be photographed at all is that the row's elapsed time is now a value it is
handed. It was `Text(_:style: .relative)`, measured against the moment of rendering, so the macOS
kind landed with only this panel's empty state.

**The Mac now has a snapshot kind**, which it never had — every Settings surface was code that nothing
rendered, and the frames were drawn at 1:1 precisely so they could become the baselines. It is a
second bundle under the same Snapshot row rather than a row of its own: the phone renders on a
simulator and the Mac on the machine itself, because there is no macOS simulator, but the question
the row answers is the same for both. **General is the first tab built from a frame**, and it landed
with its baselines in the same pull request, which is the rule that makes "we built the design"
checkable.

**Both halves are now designed, and everything drawn for the phone is built.** The client's four
screens were reviewed and redrawn against 0.0.4 on 2026-08-21 ([`design.md`](design.md)); the Mac's
seven surfaces were drawn for the first time on the same day and are recorded in
[`design-mac.md`](design-mac.md); §5's pairing round came back on 2026-08-25 and landed with it.
**Nothing is blocked on a design any more** — what is left is drawn and built, and the one frame of
§5 that is not built is unreachable rather than undrawn.

Read `design-mac.md` rather than the Mac frames: they were drawn against 0.0.6 and 0.0.7 landed
after, repairing two of the five premises they overturn and making a third obsolete.

The two halves find each other **on real hardware**: the Mac serves `/v1/health` and advertises over
Bonjour, and the phone lists it. Confirmed on Davide's iPhone against his MacBook on 2026-08-19 —
across a wired Mac and a wireless phone, so his network bridges mDNS between the two segments.

Selecting a Mac opens its own screen and both credentials lead somewhere from it. The phone has the
whole client built and tested behind that tap: it reads a Mac's health, refuses to pair when the two
ends speak different contracts, spends a pairing code from a QR or from six typed words, keeps the
token in the Keychain, and reads every route SPEC §8 serves. **What no test kind here can start is
the camera**, and the viewfinder's own preview is the one piece of this with no line a test executes.

**The composition root is wired all the way through now**, which the entry it replaces in
`decisions.md` had recorded as deliberately deferred: `MacPairing` is composed by the pull request
that drew the screens calling it, which is the day that argument said to wait for.

## Milestones

The spec's milestones, each ending in something runnable and a green suite, with a review gate.

| | Milestone | State |
|---|---|---|
| M0 | Scaffold — layout, manifest, CI, ruleset, harness, fixtures | **done** |
| — | Delivery — Xcode Cloud archives `main` to TestFlight (iOS) | **done** |
| M1 | Diff parser, display columns, word diff; path grouping into a tree | **done** |
| M2 | Git layer, worktree services, JSON store, session index, HTTP API, CLI | **done** |
| M3 | Menu bar app — settings, Bonjour, pairing, login item, connection log | **in progress** |
| M4 | Phone — pairing with pinning, discovery, worktree list, aliases, pinning | **in progress** |
| M5 | Phone — file selector, continuous scroll, highlighting, word diff, viewed state | **in progress** — the selector, the scroll, the word diff, the viewed state, the collapsed bars and hunk expansion are built; **highlighting is not**, and neither is wrap-on |
| M6 | Live updates, accessibility, ship | |

## What exists

- Every module from the spec's tree, with the layer rules enforced by the target graph.
- Both apps build and launch empty; the backend runs from a terminal.
- A golden fixture corpus covering every parser case in the spec, generated from the real `git`
  binary and committed, plus the fixture repositories the git-layer tests will drive.
- **The unified diff parser**, asserted against that corpus: hunks and line numbering, renames,
  binary and gitlink files, mode changes, conflict markers, CRLF, missing trailing newlines, paths
  with spaces and non-ASCII, column widths, and word-level segments within a line. Nothing calls it
  yet — it is a library waiting for the git layer.
- **The file selector's tree**: a pure function from a worktree's changed files to the rows the phone
  renders, with single-child directory chains compacted into one row, directories above files, and a
  deterministic order that does not inherit the one the diff arrived in.
- **Design §3's selector over it**, and the mark it reports. A second pure function joins that tree
  with each file's status, stats and viewed state and answers with the rows, the arrangement and the
  footer: a shut directory carries the summed total of everything beneath it and an open one carries
  none, a tick means every *descendant* is read rather than every child, a crowded directory arrives
  shut, and over three files — or a change set that is all one directory — the answer is flat with no
  toggle offered at all. The mark is written from the diff's file header against the file's own
  content hash, optimistically, and taken back with a sentence when the Mac refuses it.
- **The collapsed bar and hunk expansion, which finish everything of §4 a machine can judge.** A file
  the reader has read, a file too long to fetch unasked, a binary file and a rename that changed
  nothing each render as one 44pt row carrying the reason it is shut — and the two with nothing
  behind them carry no chevron, the row not even being a button. The scroll steps over every
  collapsed file, so *Load diff* is a fetch rather than a label, and opening one asks for it. Every
  hunk band carries a control for the lines above it and the lines below it, twenty a press, spliced
  **into** the diff so the control goes when the gap does; the windows are computed from git's own
  hunk arithmetic, including the `+c,0` case that names the line before a deletion rather than the
  first line of it.
- **The git client**: the closed set of questions the product asks git, the argument vector each one
  becomes, and the process that runs it — both streams drained at once, a byte cap that truncates
  rather than refuses, a ten-second budget that tears the process down without ever signalling a
  process group, and failures that carry git's own standard error. Every invocation is pinned
  against a developer's git configuration, and a fixture repository configured to defeat it proves
  that rather than leaving it asserted.
- **The whole server.** Worktree enumeration, the change set and its stats from one comparison,
  per-file diffs with the size guards, §5.5 content hashing, the JSON store, the Claude Code session
  index, and every §8 route behind bearer auth. `granita-server --add-project <path>` enables a
  repository and `--insecure-http` serves it.
- Six gating CI jobs on a pinned Xcode 26.6 / macOS 26 runner. 930 package tests in 87 suites, plus
  the snapshot suite on a simulator and the Mac's on the machine itself. **The coverage pass runs
  serially**, because measured in parallel it reported a different percentage for identical code —
  five runs of one commit spread across 96.037% and 96.121%, which a ratchet with no slack reads as a
  regression. It read one, on 0.0.16, and the re-run of the same commit passed.
- `/v1/health`, served over plain HTTP under `--insecure-http` and advertised as `_granita._tcp`
  otherwise, with the advertised port confirmed to be the one actually serving.
- **The TLS identity and pairing.** A self-signed P-256 certificate generated at first run and kept
  in the login Keychain for ten years, its subject alternative names covering the Bonjour hostname
  and every local address; its SPKI fingerprint in the `granita://pair` link the phone pins. The
  certificate is built by a DER encoder of ours in `ServerIdentityDomain`, checked byte for byte
  against the system's own parser and against an `openssl` vector. TLS goes through the **same**
  NIOTS bind that already advertises, so listening, advertising and encrypting stay one operation.
  A pairing offers two credentials for one slot — a long code for the QR and six words for when
  there is no camera — good for 120 seconds and one device, rate limited five failures a minute per
  source address, with every refusal reaching the connection log by its exact reason. The Mac
  re-binds and re-advertises on `NSWorkspace.didWakeNotification`.
- **A design for the whole client**, and a discovery screen that matches it: the row is a navigation
  row with its arrow on the trailing edge and middle truncation, searching pulses and stopping is
  still, nothing-found and failure both offer a real retry, the failure's advice is ours with the
  system's diagnostic demoted to small print, and every state sits in a 420pt centred measure on
  iPad. §3 is drawn and waiting for M5; §4's wrap-off scroll is built and the rest of it is drawn.
- **The Mac's General tab, and the kind of test that can see it.** The address this Mac serves on
  with a button that copies it, who chose the port and why it moves, when the server last bound and
  a Restart for the failure that has no notification behind it — a laptop that changed network keeps
  running and quietly stops being reachable. Not serving gets our sentence, our button straight to
  Privacy & Security › Local Network, and macOS's own string demoted to small print. The login item
  goes through `SMAppService` and **re-reads its own status**, because the ordinary first-run outcome
  is a registration that succeeds and then waits for approval — reported as success, that is an app
  that silently does not start at the next login. Twelve baselines and two window assertions hold it,
  the second of which can only be made from inside the app: window geometry is not observable from
  outside the process while Stage Manager is on.
- **The menu bar app, serving, and its menu — design §1.** It embeds the same backend, advertises
  under the name the Mac is actually called, and opens a Settings window from a status item under
  `LSUIElement` — the trap SPEC §14 asks to be implemented rather than looked up. Three symbols and
  no count; `host:port` on a row that copies it; *Pair a device…* opening the window **on Devices**
  and greyed when there is no address to encode; and a failed server leading with the refusal and
  the one thing to do about it. Eight baselines across four states, rendered as a stack because a
  `MenuBarExtra`'s menu is drawn by AppKit outside this process and cannot be photographed at all.
- **The Mac's Advanced tab.** Which git this Mac would run and whether running it works, the data
  folder with a Reveal, and `Reset All Data` — which counts what exists, repeats it as consequences
  in the confirmation, and leaves the count truthful when the reset could not be written. `Store`
  grew a `reset()`, so forgetting everything is one atomic replace rather than a file deleted behind
  the actor that owns it. Eight baselines.
- **The connection log, on a Connections tab of its own.** The last fifty attempts to reach this Mac,
  each with the reason it was served or turned away, coalesced so one polling phone cannot fill it
  and **counted** so the coalescing cannot hide how hard one is trying. Eight baselines across four
  states, which needed the row to stop deriving its own elapsed time.
- **The phone's half of the wire.** One definition of every payload both ends name, in `Core` rather
  than one copy per side — including the partial-update body whose absent-versus-null trap SPEC §8
  marks, now encoded and decoded by the same type. Over it: a pinned `URLSession` that can reach
  exactly one Mac, a client for the two routes that answer before pairing, and one for every read
  route SPEC §8 serves. Refusals arrive as a typed domain error the phone has a screen for and never
  as a status code, the contract version travels on every request, and a Mac serving an older
  contract is caught by `/v1/health` **before** a two-minute single-use code is spent on it. The
  token goes into the Keychain, per Mac, and is the only copy there is. **The two halves are proven
  against each other**, not each against its own idea of the contract: the phone's real client runs
  against the Mac's real router in one process, pairing with a code the Mac issued and with the six
  words under it, and driving the partial update through all three of its states.
- **The worktree sidebar, design §2, titled after the Mac it is reading.** Every checkout an agent has
  been working in: grouped under one Pinned section and then by project, or flat and most recently changed
  first, with pins above everything in both. A name the reader can trust rendered proportionally and
  a generated directory name rendered monospaced, because that font switch encodes the whole question
  of whether the string means anything. Primary checkout and detachment earn a word rather than a
  glyph — detachment only where the name fell through to the directory — an unborn head takes the
  stats slot rather than reporting the whole repository, and the file count is the first field to go
  when the line will not fit. Swiping renames or pins; the rename sheet **offers** the agent's own
  session summary rather than prefilling it, and its footer says what the row will read after Save,
  live. Quiet worktrees are hidden and the footer says how many, tappably, so that count and the way
  back to those rows are one control. Fifteen states across three suites, sixty baselines.
- **How the sidebar was left, across launches**, in user defaults: the arrangement and the quiet
  switch. That is what design §2 chose a toolbar menu over a segmented band for — a preference set in
  week one and then forgotten — and a control the reader has to set again every launch is one they
  would rather not have been offered.
- **One model for the client's connection unit**, replacing the discovery view model. Nothing in the
  client is named `…ViewModel` any more. Joining a Mac is a **use case** in `Domain` rather than a
  method on the model, and the model carries the browse and one attempt at a time: opening a Mac's
  own screen clears what the last attempt left behind, and the retry is handed the Mac it is titled
  after rather than reading whatever the model still happens to hold. `MacPairing.rememberedMacs()`
  — `alreadyPaired()` until 0.4.1 — is what decides where a row goes, and the model holds a copy of
  it again for the first time with a screen that reads it: the third time that property has existed,
  and the one where something renders it.
- **The four pairing screens and the iPad's split view, with their baselines.** The entry screen,
  the viewfinder against a drawn still, the six-word field in five states and the outcome's five
  appearances; plus a suite that photographs the four *pushes* rather than the four screens, which
  is the half a view test cannot reach. The split view has one of the fallback its destination draws
  when a chosen worktree is no longer in the list.
- An Xcode Cloud workflow archiving `main` to TestFlight for internal testers.

## Verified against the real environment

Findings from the spec's verify-first pass are in [`verification.md`](verification.md). The short
version: every git trap in the spec reproduces on git 2.52.0 and 2.55.0, all three dependencies are
current and resolve, and the module graph compiles.

**The TLS and pairing path is verified end to end on this machine**, on 2026-08-21, against
`granita-server --pair` over the advertised Bonjour port: `curl --pinnedpubkey` reached
`/v1/health`; the wrong pin was refused with `SSL: public key does not match pinned public key`; the
six-word code — typed in capitals with spaces — redeemed for a token; that token read `/v1/projects`
while an unauthenticated request got `unauthorized`; a run of guesses was cut off at the fifth with
`rateLimited`; and the fingerprint was **identical across a restart**, which is the property every
paired device depends on and the one that was broken twice before it was right.

**The pairing spine's hang was reproduced and its fix confirmed in the simulator**, on 2026-08-25,
by seeding the navigation path and driving the model with a Mac that agrees — no camera and no
Accessibility grant needed, which is what made it reachable at all after UI automation was ruled out.
Before: the model reached `finished(.paired)` and the stack was still three deep three seconds later,
under §5's in-flight frame. After: the stack replaces itself with the worktree list. The entry
screen's own log is the evidence — `onDisappear`, then three more body evaluations, then nothing from
`onChange`. Recorded in [`decisions.md`](decisions.md).

**`KeychainPairingTokenStore` has now been executed**, in the same run and for the first time
anywhere: every call returned in about five milliseconds with `errSecMissingEntitlement`, an unsigned
simulator build having no keychain access group. It answers, and it answers fast — so the Keychain is
not what any spinner in this app has ever been waiting for.

**The lock file and the verbose switch's mechanism are verified by running them**, on 2026-08-24,
against two `granita-server` processes and a `--store` in a temporary directory — no GUI involved, so
none of it needed the Accessibility grant.

- A second process against the same store printed `granita-server (process 2561) is already using
  /tmp/…/granita.json. Quit it and try again.` and exited 1. `--add-project` was refused the same
  way, before the document was touched.
- The lock file beside the store held `{"processIdentifier":2561,"processName":"granita-server"}`.
- **The crash case, which is the one a pid file gets wrong:** the holder was `kill -9`'d, leaving the
  stale file naming a process that no longer exists. The next process took the lock anyway and
  rewrote the holder — the kernel released it when the descriptor closed, exactly as designed.
- **Verbosity moves on a server that has been running since launch**, which is the claim the whole
  seam exists for. With the switch off a request wrote nothing; turning it on mid-run and repeating
  the request wrote `GET /v1/health` and `GET /v1/health → 200` under
  `[dev.fardavide.granita:requests]`; turning it off again mid-run and making two more requests wrote
  nothing further. Read with `/usr/bin/log show` — `log` is a zsh builtin and returns silence.
- The lines came back at type `Df`, which is **default**, not debug. That is the level the unified log
  persists, and it is the one thing here no test in this repository could have caught.

Still unverified, because each needs code that does not exist yet:

- Highlightr's throughput on a 200-line Swift block, measured on device (M5).
- Login-item registration (M3). The `MenuBarExtra` plus `Settings` pattern under `LSUIElement` is
  now implemented and verified on macOS 26.
- Character-wrapping height arithmetic against measured heights (M5). Wrap-on is not built; the
  wrap-off scroll that would be its alternative is, and which of the two ships as the default is a
  question only a thumb answers.
- **Whether §4's scroll feels right on a phone**, which design §4 names as the reason to build the
  wrap-off mode first. A two-axis scroll inside a vertical one that must never reflow is the hardest
  gesture in this product; it is built and wired, so it can be opened and tried. If it does not
  survive, character wrapping becomes the default and half of §4's gutter arithmetic stops
  mattering.
- **Pinned trust evaluation against App Transport Security on a real iPhone (M4).** Both halves now
  exist — the Mac's identity and the phone's `URLSessionDelegate` — and what a device has not yet
  said is whether a delegate that compares the fingerprint instead of evaluating satisfies ATS.
  `decisions.md` records the constraint: the default evaluation must be **replaced**, not added to,
  because the OS refuses a ten-year certificate outright.
- **The phone's Keychain, at all.** `KeychainPairingTokenStore` has never been run. A SwiftPM test
  binary is unsigned and has no keychain, and the screen that would reach it on a device does not
  exist yet — so unlike the Mac's identity store, which was proven by running the server, this one
  is asserted only by the fake behind its protocol. The first pairing on hardware is what confirms
  it.
- **Waking from sleep, seen on hardware.** The rebinding loop is asserted against a fake, and
  `NSWorkspace.didWakeNotification` reaching it is not something a host test can produce.

## Configuration Davide still owns

Tracked here because none of it can be done from a CLI. See the handover in the pull request that
sets up delivery.

- ~~Apple Developer Program membership.~~ Done. A Developer ID Application certificate is still
  needed to distribute the **Mac** app outside the store, but not to develop or to ship the phone
  app — the existing Apple Development identity is a real signature, which is all the local network
  privacy trap requires.
- ~~Bundle identifier, App Store Connect record, internal tester group, agreements, Apple's GitHub
  app, and the iOS Xcode Cloud workflow.~~ Done — build 1 reached TestFlight.
- A **second Xcode Cloud workflow for the Mac app**, archiving with Developer ID and notarising.
  Not started; the Mac app runs locally in the meantime.
- The first project folder to add.


## What to pick up next

~~**The connection does not persist, and it is two defects rather than one.**~~ Both confirmed by
reading the code after Davide hit them on 26 August; **both fixed in 0.4.1**, after he hit the first
one again — *every single time I tap on my Mac, it asks me to do QR code or six words*.

- ~~**Nothing joins a discovered Mac to a stored token.**~~ The join is the **Bonjour instance name**,
  not the identifier the Mac issues: a browse result carries it, and `/v1/pair`'s `serverInstanceId`
  arrives only after the question has been asked. So no TXT record and no `/v1/health` field — the
  proposal recorded here would have worked and cost a round trip before the phone knew what to pin.
  What that reading got right is the part it called unsolved: the Keychain now stores the whole
  pairing, **fingerprint included**, so a reconnection pins the key that pairing bought rather than
  trusting first contact a second time.
- ~~**Nothing re-resolves via Bonjour before using a stored address.**~~ No address is stored at all
  now, which is `SPEC.md` §10 satisfied by construction rather than by remembering to re-resolve: the
  lookup happens on the first request to a remembered Mac, and an unreachable read throws the answer
  away so the next one asks again.

**Syntax highlighting is what is left of M5 that a machine can build, and 0.4.2 unblocked it.**
Highlightr is declared on `ClientViewerUi` and nothing imports it. `SPEC.md` §10 is prescriptive
about it — per file per side, never per hunk, the six-part cache key, skip over 100 KB or 4,000 lines
or a nil language, visible file first, render unhighlighted and upgrade in place — and its throughput
on a 200-line Swift block is an unverified item that needs a device.

**What was blocking it was not the specification but a collision the design never drew.** §4 has no
highlighting section at all — its eight subsections stop short of it — and the treatment it *did*
specify for word segments spent the text colour a lexer needs. That is settled as of 0.4.2 and the
colour is free. Two things `SPEC.md` does not anticipate are worth knowing before the next attempt:
**a language Highlightr does not recognise silently falls back to auto-detection** rather than
refusing, which over a hunk union will confidently lex the wrong grammar, so the claimed language has
to be checked against `supportedLanguages()` first; and **the six-part cache key is one part short**,
because `contentHash` is a fact about the file while what gets lexed is a subset of it the reader can
widen — an expansion grows the string and leaves the hash alone, so an entry made before one would be
indexed against lines that have moved.

**The other two are a thumb's to settle.** The file header's second form is **provisional pending a
device** — it ships in one form because a pinned header that is shorter when pinned reflows a slot
above the viewport — and wrap-on is the alternative to a gesture only a thumb can judge.

**And the coverage gate has a structural debt this slice made visible.** Five controls landed on
three views, and an action closure in a view body is uncoverable by every test kind that runs here.
The Snapshot row is short by 4 regions and 3 lines against `main` even after three genuine
unphotographed fallbacks were found and covered — a wholly added file, a wholly deleted file and the
diff screen over a clean worktree. What closes it for good is the `ui` target, which needs the
Accessibility grant on the Mac and an `Apps/GranitaMobileUiTests` that does not exist. See "Waiting
on Davide".

**M4's remaining half was pairing and it is built**, and the adversarial pass over it is landed too,
so what is left of that slice is what a machine cannot answer, two calls that are Davide's, and a
version that has not moved.

- **Press it on a phone**, and 0.3.0 and 0.4.0 add nine controls no test kind here can reach: the
  *N files* button that opens the drawer, a file row that jumps the scroll, a directory row that
  opens and shuts, the circle in the file header that marks a file read, **the collapsed bar that
  opens a file, the chevron in the header that shuts one, and the two on each hunk band that show the
  lines above and below it**. Every one is asserted at the model and photographed at rest; **an
  action closure in a screen is uncoverable by any test kind that runs here**, and there is still no
  iOS UI test target. Two to watch above the others: the drawer, because design §3's whole argument
  is that it stays up while the diff scrolls behind it and whether
  `presentationBackgroundInteraction` delivers that is a thumb's answer; and **the bar for a file
  over 500 lines, because it is the one control here that is also a fetch** — pressing it must turn
  the bar into a header and then fill it, and nothing that runs on this machine can watch that happen.
- **Press an expand control twice inside one round trip.** Both presses compute their window before
  either lands, so both ask for the same lines and both splice them — twenty lines of context
  appearing twice, with the gutter numbers saying so. It is **not guarded**, deliberately: the guard
  is a branch no test kind here can drive, since it needs two calls genuinely overlapping and
  therefore a fake that holds a request open, and an untested branch is worse than a defect a device
  can show. Whether it happens at LAN speed is what a thumb answers.
- **And a measurement while the phone is in hand: whether a 44pt hunk band is too much.** Design §4
  asks for that hit area in as many words and it is four times the height of the band before it, so a
  file with five hunks spends 220pt on controls. A hunk with nothing to expand keeps the thin band,
  which bounds it; whether the ones that do not are worth their room is a question a drawing could
  not answer.
- **Press it on a phone**, and there is more to press now: tapping a worktree opens the diff. The
  camera, the Keychain, the local-network prompt and a QR held across a
  room are four things this Mac cannot produce, and the viewfinder's preview is the one piece of the
  slice no test kind that runs here executes a line of. **Three of the six defects the adversarial
  pass found were about what a screen is showing rather than what a model holds** — a title, a
  frozen frame, and a keyboard key that submitted nothing — which is the class a phone in hand
  catches in a minute and nothing here catches at all.
- ~~**The list is still titled *Worktrees*, not after the Mac.**~~ Landed in 0.1.1. `PairedMac`
  carries the name, `MacJoining.pair` is told which Mac it is spending against, and the title is set
  inside the sidebar rather than around it. It is **inline** rather than large, which the first
  render decided: a 34pt title drops a Bonjour name's tail, and the tail is the half that says which
  Mac. Both calls are in `decisions.md` and `design.md` §2.
- **`.notReached(.localNetworkDenied)` reaches a screen §5 never drew.** Six typed words against a
  Mac the phone may not speak to at all is a real ending with a real remedy, and the outcome screen
  renders it out of the vocabulary it has rather than out of a frame. Davide's call, in
  `decisions.md`.
- **0.1.0's changelog entry does not mention the defect pass**, which is a call rather than an
  oversight: the version is already bumped and the release has not merged, so these six fixes are
  part of it rather than a release of their own. Three of them change what a reader sees — a retry
  that can no longer reach the wrong Mac, a Go key that submits, and an iPad row that opens a screen
  titled after the worktree — and the entry as written promises the third of those outright.


**M3, the menu bar app: everything that is not a screen is done.** The Mac app runs the same backend
the executable runs, advertises it over TLS under an identity it generated for itself, says where it
is listening, re-binds when the Mac wakes, and has a Settings window whose Advanced tab shows the
last fifty connection attempts with the reason each was turned away.

**Every drawn Mac surface is now built**, with its baselines, and as of 0.0.18 nothing on the Mac is
left of M3 except the milestone's acceptance:

- ~~**Settings, and one tab is left.**~~ All five are built as of 0.0.15. §5's Allow-from-the-Mac
  path stays out until its frames exist.
- ~~**The pairing QR.**~~ Built, at four points per module — sized from the module count rather than
  into a fixed square, because a 53-module code squeezed into 240pt puts some modules at four points
  and others at five, which is what a scanner reads as noise.
- ~~**§1, the status item and its menu, and the rest of §2.**~~ Built in 0.0.16, with baselines,
  and the Mac's design review was deleted with them — it was the last two sections in it.
- ~~**A logging layer, which nothing has needed until now.**~~ Built in 0.0.17: a seam in `Core`,
  `os.Logger` behind it, and call sites at the request boundary and every git invocation.
- ~~**What §7 still owes, and it is one pull request rather than two.**~~ Landed in 0.0.18, as one
  pull request. The estimate was two baselines short of the truth: the lock also cost General a
  state and the menu a picture, because the refusal has to be read where a reader looks first and
  not only on the tab they would reach last.

**Read `design-mac.md`, which is the whole record.** The frames are gone; the sheet keeps every call
beside the alternative it beat, both open calls with the measurements that answered them, and which
of the five premises the drawings overturned still stand.

**The milestone's acceptance — pairing from a real device on the LAN — is the one thing left that
this machine cannot answer**, and it is what earns the minor version. Everything it depends on is
proven from a terminal; see "Verified against the real environment".

Smaller things still open in these modules:

- **The `xcrun -f git` step.** Both composition roots now share one probe of three fixed paths;
  `xcrun` is itself a subprocess and still wants its own seam.
- ~~**Pinning the JSON encoder.**~~ Done. Both the request context and the phone's decoder now say
  `.iso8601` in as many words, so a dependency changing its default moves neither end silently.
- ~~**The store's lock file.**~~ Built in 0.0.18. `flock` beside the document, the second process to
  start refuses and names the one holding it, and both composition roots refuse the same way — the
  app into a run state that General and Advanced read, the executable into stderr and a non-zero
  exit.
- ~~**The dirty-worktree count** beside the menu bar icon.~~ **Measured on 2026-08-22, and the answer
  is no.** `/v1/projects` over ten of Davide's real repositories — 38 worktrees, one Android monorepo
  carrying 16 — took **122.7 seconds**. The design offered two branches, "tens of milliseconds" and
  "seconds", and two minutes is neither: a menu that computes this on open never opens. The label is
  the icon alone and the count is not built. It becomes affordable only when something asks git the
  cheap question — `projects()` builds a whole change set per worktree, every path and stat and
  revision, to evaluate one boolean.
- **The Bonjour TXT record**, which stopped blocking anything in 0.4.1 and is now only a spec item.
  SPEC §8 wants `apiVersion` and a stable `serverInstanceID` in it, and `NWEndpoint.service` carries
  no TXT record — so it still needs a way in through the same bind rather than a second `NWListener`,
  which is the trap §8 exists to warn about. What it was believed to be blocking, the join between a
  discovered Mac and a stored pairing, is done without it: the pairing is filed under the Bonjour
  instance name a browse result already carries, and the SPKI pin rather than any identifier is what
  proves the machine. Design §1's *Recent* and *Other Macs* sections are therefore buildable now, and
  the list still ships as the single unlabelled section — not for want of the history, but because
  two sections are a change to a drawn screen and this slice changed no pixels.
- **`Pairing.instanceId` is a `UUID()` per process**, so it has never been stable across a restart of
  the Mac, and `ServerInstanceId`'s own documentation said the opposite for four releases. Nothing
  depends on it any more — the phone stopped keying pairings on it in 0.4.1 — so this is a wrong
  comment beside a value the wire still carries rather than a defect anyone can hit. It becomes real
  the day something wants to tell two Macs apart by anything other than their key.
- ~~**Revoking a device** has a store method and no route.~~ Built with the Devices tab in 0.0.15,
  and its refusal is drawn: a Revoke that leaves the row where it was is a control that did nothing,
  on the one tab where doing nothing means a phone can still read this Mac.

## Waiting on Davide

- ~~**Whether §3 should have deleted *Choose a worktree*, and whether the split screen's doubled
  destination should collapse.**~~ Answered on 27 August 2026, and both stand as they were:
  `NoWorktreeChosenView` stays because design §2 asks for an unavailable-content view in the empty
  detail column in as many words, and the doubled `navigationDestination` stays doubled because
  removing a declaration to find out which container claims a tap is how this app shipped a row that
  did nothing. In [`decisions.md`](decisions.md).

- **The coverage gate's structural debt, which is now costing pull requests.** An action closure in a
  view body is uncoverable by every test kind that runs here, so a slice that adds controls lowers
  the Snapshot row whatever else it does — 0.3.1 lost one region to a Copy button and 0.4.0 is short
  by 4 regions and 3 lines after five. The genuine fallbacks nearby have been found and covered;
  what is left is either the `ui` target — which needs the Accessibility grant **and** an
  `Apps/GranitaMobileUiTests` that has never existed — or Davide deciding the row may hold rather
  than climb. Neither is a call to make from inside a pull request.

- **The Accessibility grant, under System Settings › Privacy & Security › Accessibility.** It is the
  last thing between `make ui-tests-mac` and a green run, and it is now blocking **eleven** shipped
  controls rather than a target: the Devices tab's `Revoke`, `New Code`, `Open General` and 0.3.1's
  Copy beside the six words — whose pasteboard content is asserted at the model, which is exactly as
  far as this machine can take it — the
  connection log's `Pair…`, 0.0.16's three menu bar rows — the status line that copies, *Pair a
  device…* and *Open Local Network Settings…* — and 0.0.18's three, the verbose switch, *Open in
  Console* and *Quit Granita*. **`Settings…` is not among them and was wrongly listed here until
  0.0.18**: it worked before 0.0.16 and its observable effect has not changed since, so counting it
  overstated what the grant is holding up. Every one of the ten is asserted at the model and
  none has been pressed. That is the exact shape of the dead control this project shipped for eight
  releases, and no baseline can see it: a `TabView` outside a `Settings` scene draws no tab bar, and
  a `MenuBarExtra`'s menu is drawn by AppKit outside this process entirely. **Pressing them means
  driving this Mac while Davide is using it, which he ruled out on 2026-08-23**, so it is his to
  grant or his to press. The three menu rows are reached by clicking the status item; the copy is
  checked by pasting, and *Pair a device…* must land on **Devices** — press it, switch to Advanced,
  and press it again, because the second press is the one a counter would have swallowed.

  **The failure message changed on 2026-08-24, and it is a better one than the one recorded before.**
  `make ui-tests-mac` had been documented as dying with *Timed out while enabling automation mode*,
  which names no setting. It now dies with `The test runner failed to initialize for UI testing.
  (Underlying Error: Authentication canceled. System authentication is running.)` — macOS raising an
  authorisation prompt rather than silently refusing. The grant is still the answer; what is new is
  that the system asks for it rather than timing out.

  **The bundle itself is ordinary XCUITest, the same kind the phone would use.** What differs is the
  platform and not the test style: an iOS UI test runs inside a simulator that enables automation for
  itself, while a macOS one drives the real desktop and macOS gates that behind TCC. No build
  setting, entitlement or code change reaches it.

- ~~**A design round trip for the Mac's own surfaces.**~~ Came back on 2026-08-21 and is recorded in
  [`design-mac.md`](design-mac.md). Nothing in the Settings window is blocked on a drawing any more,
  with the one exception below.
- **A design round trip for allowing a device from the Mac**, asked for on 2026-08-22 and the only
  Mac surface now without frames. The case is real and Davide has hit it: on Screens, looking at the
  Mac *from the phone being paired*, the camera and the screen are the same device, so the QR cannot
  be scanned and the way out today is a second device and a screenshot. The QR itself stays — it was
  re-opened in the same exchange and settled unchanged. What is missing is both halves: nothing on
  the Mac knows a phone exists until that phone presents a credential, so "the devices on the net" is
  not a list anything can produce, and inventing an announcement is a change to SPEC §8 rather than a
  layout. §5's drawn half — the QR, the six words, the countdown, the paired rows with Revoke —
  ships without it.
- **Pairing from a real device on the LAN**, which is M3's acceptance and cannot be answered from
  this machine — the simulator does not implement local network privacy at all. The phone has its
  pairing screens now, so the way to try it is the app; `make run` with `--pair` is still the way to
  read what the Mac is offering, since it prints a `granita://pair` link and six words every two
  minutes and the fingerprint on that line is what the phone must pin.
- ~~**A design for the QR scanner and the pairing screen.**~~ Came back on 2026-08-25 and is
  recorded in [`design.md`](design.md) §5 — four screens, twelve states, and the finding that the
  six words carry no key. Built in the same slice, with its baselines. It had been outstanding for
  eight releases without anyone waiting on an answer, because **the prompt had never been written**;
  it was written on 2026-08-24 and the round trip took a day.
- **The refused-permission path, seen on device.** Granting works and is confirmed, and 0.0.4 fixed
  the false refusal Davide hit by backgrounding the app and coming back. What is still unconfirmed on
  hardware is the true one: whether a browser that iOS really is withholding permission from dies
  three times over and reaches the Settings screen within a couple of seconds, rather than sitting on
  "Looking for your Mac". The simulator does not implement local network privacy at all, so only a
  device can say. Turn it off under Settings › Granita › Local Network to check, then turn it back on
  without relaunching — the screen should find the Mac again on its own within five seconds.
- A **second Xcode Cloud workflow for the Mac app**, archiving with Developer ID and notarising.
  Not started; the Mac app runs locally in the meantime, and only distribution needs it.
