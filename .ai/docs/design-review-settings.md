# The review's settings, and where a review lives

The design return of 17 September 2026, drawn against 0.14.2 for issues
[#64](https://github.com/fardavide/granita/issues/64) and
[#98](https://github.com/fardavide/granita/issues/98). Frames in
[`design/granita-review-settings-design-review.html`](design/granita-review-settings-design-review.html),
and they go when the last section here ships.

## The rule the whole return is drawn from

**A Granita surface never shows a value it will not use.**

Davide's answer of 17 September — the phone keeps a local copy and reconciles, the Mac is the source
of truth — settles the storage and does not settle what a screen may claim. So the narrower rule
above governs every state here. The Mac wins at **read** time, when a fresh device asks what the
settings are. The phone wins at **write** time, because the alternative is discarding something a
reader typed on a screen that accepted it.

A closed laptop is the normal condition, not the error. No surface here may be inert when the Mac is
away.

Two states are removed before they are drawn, and neither may be added back:

- **No loading state on the phone's Settings screen.** It opens on the last values it read or on the
  defaults, and both are values it would honour, so there is nothing for a spinner to stand in front
  of.
- **No blocked copy.** The copy button never waits for the Mac. A review that was never pushed and
  gets pasted anyway is a complete review in the reader's hand.

**The one thing here that can be lost** is an opening line the reader typed and did not commit,
because a text field's value is not written anywhere until editing ends. So the opening line commits
locally on a pause in typing and sends on end of editing. A keystroke is never a request: 29
characters would be 29 round trips, and the Mac's store already coalesces at one second, which is its
debounce and not the wire's.

## The phone's Settings sheet

### The way in is the worktree sidebar's toolbar menu

The sidebar is already per-Mac — its title is that Mac's name, its back button returns to the Mac
list, its toolbar menu already holds the arrangement toggle. Settings that live on a Mac belong in
the menu of the screen that is about that Mac. One item, third in the menu, above the toggle, because
it is wanted more often.

> Rejected: a tab bar. It takes 49pt of every diff, permanently, for a screen opened twice a year,
> and a container change here has a history — a collapsed split view once drew its chrome and none of
> its rows.
>
> Rejected: the diff screen's toolbar. That bar is for reading code, it is where the review capsule
> and the file count already compete, and it is per-worktree rather than per-Mac. A settings door
> there would be the fourth thing on a 44pt bar and the first not about the file in front of the
> reader.

### It is a sheet, and the same sheet on both devices

A full-height sheet with its own navigation bar and one *Done*, presented from the sidebar. On the
iPad the same view is a form sheet, 540 × 620pt centred over the three columns; the diff behind it is
dimmed rather than resized, so nothing the reader was reading moves.

> Rejected: a pushed screen. The phone's sidebar stack already spends its back button on the Mac
> list, so a push makes *Back* mean two things one tap apart. On the iPad a push lands in whichever
> of three columns declared the destination, which is the bug the discovery row shipped for eight
> releases.

It should feel like a preference pane the reader can close without wondering whether anything was
saved — dull, immediate, and never between them and the code.

### Two controls and a receipt

1. **The opening line.** One section, one field, full width, holding real editable text rather than a
   placeholder. Committed locally on a pause, sent on end of editing. Cleared to nothing is a legal
   answer: the document then begins with its first comment. *Reset* is how the default comes back,
   not the delete key.
2. **The label style.** A two-segment picker whose segments are the thing itself — `A. B. C.` and
   `1. 2. 3.` — so the setting is its own preview. Not a popup menu, which would hide one option
   behind a tap and show the chosen one as a word.
3. **The receipt.** A third section, monospaced, four lines, showing the first two lines of a review
   and the first comment's head. It exists because the two controls are about a document the reader
   cannot see from here, and it is the only place both settings are legible together. It is text,
   not a control.

**The default is told by a sentence and by the absence of *Reset*** — never by grey text. A
placeholder would be a lie: here the words are the exact string that will be exported, and Davide's
own sentence is *"you will see the default one, and you will be able to edit it"*.

**The highlighting theme, when [#70](https://github.com/fardavide/granita/issues/70) lands, is a
fourth section and is this phone's**, not the Mac's: it renders on this screen at this brightness in
this appearance, it cannot fail, and it needs no round trip. The Mac owns what the review *says*; the
phone owns what this device *shows*. That divide is what keeps the footer sentences true when a
second group arrives.

### The seven states are one screen with one changing footer

The controls never move and never disable except in the one state where there is nowhere for a value
to go. The sentence under them says what this phone and that Mac currently disagree about.

| State | Footer | Notes |
|---|---|---|
| Loaded, edited earlier | "Every review you copy begins with this line. Stored on `<Mac>`, so any device reading it starts the same way." | *Reset* present, because the value differs from the default |
| Never changed | "…is the default. Every review you copy begins with it until you change it. Stored on `<Mac>`." | No *Reset* row — nothing to reset |
| The field has focus | unchanged | The keyboard takes 311pt; the field is the first row of the first section, so it needs no scroll-to-focus |
| The write is in flight | one sentence replaced, nothing else | No spinner, no disabled control, no confirmation afterwards. A LAN write that succeeds in 40ms should not leave a mark |
| The Mac is unreachable | "`<Mac>` is not reachable. What you change is kept on this phone and sent when it answers." | Editable and queued. An amber dot, the same figure the stale comment row uses, is the only mark |
| The Mac said no | "`<Mac>` cannot save this, so it still has the old line. This phone will keep using the one above." | Our sentence with the store's reason as small print. No retry button |
| No Mac at all | "These are stored on the Mac you read from, so there is nowhere to keep them yet. Reviews begin with the default line above." | Both controls in the defaults and off, receipt section gone, one row leading to pairing |

**Unreachable is editable and queued, not read-only.** Read-only is the honest-looking option and it
fails on frequency: a closed laptop is the normal condition, so read-only means the two controls are
unusable most of the time the app is open — including a whole train journey spent reading a diff that
was already fetched. It also inverts the product's posture, making the phone the thing that cannot
act.

**A queued edit carries only the fields the reader changed**, using the presence-versus-null idiom
the worktree PATCH already spells out. That is what makes editing safe against a Mac whose values
this phone has never read: a queued opening line cannot overwrite a label style it never saw.

**Never paired is reachable and inert.** Discoverability was the real half of that question;
operability is not. An unreachable Mac will answer later, so a value has somewhere to go; a phone
with no Mac has nowhere, ever, and a control that accepts a value it will discard is worse than one
plainly off. Such a reader also has no review to copy, so nothing is being withheld.

**A Mac too old to store these** reads as the never-paired state with its own sentence: "Granita on
`<Mac>` is too old to store this. Update it, or keep these on this phone." Nothing queues, because
the addressee cannot receive it.

## The composer and the review sheet gain one line of type

**Sync state appears in exactly one place** — a caption directly above the copy button, in the slot
the footer already reserves for a sentence about that button — **and nowhere else.** Not in the
gutter, not on a rail, not on a row, not in the composer. The diff gains nothing at all and is
byte-identical to its shipped baselines.

The rail is this app's one overloaded object: the same indigo in the gutter, the instruction bar, the
composer's anchor and the review row, and its whole job is to say *a row here and a mark there are
the same thing*. Spending it on a fact that changes nothing the reader can do while reading code
would cost the review feature its one piece of vocabulary.

**The copy is where it does change something.** A reader about to paste is deciding whether this
document is everything they wrote; a reader about to press *Clear* is deciding whether it is safe to
destroy. Those are the two moments, they are three taps apart, and both are in the sheet.

**Per review, not per comment, and a count rather than a word** — two of five and five of five are
different decisions. No spinner and no progress: the push is one request for the whole review, so
there is nothing to count. It ends by the caption disappearing; the absence of a sentence is the good
state everywhere in this return.

**The composer gains nothing.** It is 300pt with the keyboard up, its job is one comment, and the
comment is saved when it returns. A sync state there would be a report about the previous comment on
the screen for writing the next one. **One string in it does change**: its confirmation may no longer
claim the comment is only on this phone, because once a review lives on the Mac that is a lie in the
one place the app is deliberately explicit about where a review lives.

**Two devices reviewing one worktree take the union, in document order, with one line saying so.**
No merge screen, no keep-mine, no attribution on a row — comments are anchored to different lines, so
the union is almost always what the reader wants, and swipe-to-delete is already the control for the
rest. The line goes under the section label, and it does not name the device: naming it starts making
this a review with two authors. The header count stays the reader's count, not the Mac's.

**A refused push takes two lines — ours and the store's — and takes nothing away.** "`<Mac>` cannot
store this review." The copy button stays filled, stays indigo, stays enabled. No retry: the push
already retries on every change and every reconnect, and the reader's next move is the button
underneath, which works.

**The clear alert has three wordings, chosen by what is true when it opens:** all of it on the Mac,
some of it, or none of it — the last being the shipped sentence unchanged. The *paste first* warning
keeps its own wording, because it is about the paste rather than about storage.

## The Mac's sixth tab, called Review, fourth in the row

General, Projects, Devices, **Review**, Connections, Advanced. The first four are the pipeline
outward — this Mac, what it serves, who may read it, what comes back — then live diagnostics, then
the drawer.

The window already ships **five** tabs rather than the specification's four, because the connection
log was lifted out of Advanced on the grounds that it is read under pressure and must not sit one
mis-click from the button that unpairs every device. So the question is not whether the four-tab row
may be broken; it is whether these two controls earn it on the same terms, and they do: the review is
its own subject, it is the only pane whose values a phone reads and writes, and it is the first thing
in this window that is not about serving.

> Rejected: General. Its subject is this Mac's address and whether anything is listening, and there
> is no port row to hide a review section behind — it would be a third of the tab's content. It is
> also the pane a reader opens when something is wrong, which is the worst place for a text field
> about the wording of a document.
>
> Rejected: Advanced. Neither control is advanced, and they would share a pane with *Reset all data*
> — the exact objection that moved the connection log out.
>
> Rejected: Devices. It is 560pt of QR and countdown, and a text field under a live pairing code is
> a field nobody will find.
>
> Rejected: Mac-side omission. Davide asked for both ends, and a store holding a setting no local
> surface can show is a store you debug with a text editor.

Two rows in one section in the Mac's own idiom: a plain text field committed on focus loss, and a
segmented control whose two segments are the thing they choose. *Reset* sits at the trailing edge of
the field's row, disabled while the value is the default — the Mac can afford a visibly-disabled
control where the phone's row cannot. Below them, the same receipt the phone draws, which is the only
place either app shows a fenced comment block before it is pasted.

**If the tab bar overflows at 620pt, widen the window to 680** rather than rename a tab or accept the
overflow chevron. The window is a fixed size already, set by the QR in Devices, so widening it is a
constant rather than a layout change.

**A stored-reviews count row** is the one thing here not in the brief, and it is not a review browser:
two numbers, because reviews now accumulate per worktree and worktrees are created and destroyed by
an agent. It is where a reader sees the store is not growing without bound. **No Mac-side clear
button** — clearing is the reader's act at the moment of pasting, and a Mac-side button would destroy
a review a phone might be holding unsent. Pruning is a rule, not a control.

## The open calls, answered

- **Placeholders in the opening line: no**, and it costs nothing to add later. Any fact can be
  interpolated at export whenever it is wanted, with no change to the store or the wire. What v1
  would be buying is a template language — escaping for a literal brace, a rule for an unknown token,
  a rule for an empty value, and a second thing for the field's footer to explain.
- **A fifth tab: yes, fourth position, named Review.**
- **A not-yet-synced comment visible at all: only at the copy**, per review, with a count.
- **Settings reachable with no Mac paired: yes, and inert.**

## Where this disagrees with `SPEC.md`

The spec wins until Davide says otherwise. Four disagreements are worth writing down:

1. **§9's four-tab settings window.** Five ship; this makes six. The departure is the same one, made
   for the same reason, and belongs in `decisions.md` with the window's fixed width noted as the
   constraint that could overturn it.
2. **§8's compatibility rule** says the client refuses to pair on a contract mismatch and any route
   426s on a newer client. The settings and review routes need to **404 for an older Mac** instead,
   so a newer phone degrades to its local values rather than refusing the Mac entirely. That is a
   change to §8 and the one the return most wants recorded.
3. **§9 names `viewed` as the only unbounded collection**, which stops being true this slice. Reviews
   accumulate per worktree and a comment carries an excerpt, so a review is kilobytes rather than
   bytes. The prune rule and the cap need a sentence of their own in §9.
4. **§10 says the code size is not a setting.** Two earlier rounds leaned on that sentence to argue
   what Dynamic Type may scale. Either §10 loses the claim, or the phone's Settings screen is where
   the setting lands, in the device-local group beside #70's theme.

Storage is untouched: the schema version bumps and the old decoder stays, exactly as §9 instructs.
Nothing here needs queries — the phone reads one settings object and one review per worktree, both by
key — so JSON, one actor, atomic replace all stand.

## What was built, and the three places it departs from the frames

All three surfaces are built. Three calls were made differently, each for a reason the frames could
not have known:

1. **The sidebar's toolbar menu is no longer gated on the list being arrangeable.** It was, so a Mac
   with nothing to arrange drew no menu — and the only door to these settings would have been behind
   it. The arrangement rows stay conditional; the settings row does not.
2. **The sheet is presented by the split screen rather than by the sidebar.** A sheet presented from
   a `NavigationSplitView` column is bounded by that column, which would have made the iPad's form
   sheet land in the 320pt sidebar instead of centred over the three columns.
3. **No focused-with-keyboard subject.** The frames ask for one. The keyboard is geometry that
   arrives asynchronously and lands on whichever render is laying out when it does — the review
   sheet's own column baseline was lost to exactly that, four CI runs running. The field is the first
   row of the first section, so what the frame would prove is that the section below scrolls away,
   and that is not worth a flaky suite.

**The Mac's stored-review counts are two numbers on the Review pane**, as the return proposed, rather
than in Advanced beside the project and device counts. Advanced is where a reader goes when something
is wrong; the counts are about a collection this slice introduced, and they belong beside the controls
that shape it.

## What to photograph

- **The phone's Settings sheet:** 7 states × iPhone and iPad × light and dark, plus one iPhone frame
  at xxLarge and one with the keyboard raised. The iPad answer is the same view as a form sheet and
  the dark answer is an appearance swap, so both are stated once and drawn twice rather than seven
  times, which is how the existing suites are built.
- **The composer's 16 do not change.**
- **The review sheet gains four subjects** — written-not-yet-sent, reconciling, two devices, refused —
  at 16 new images, plus one for each clear-alert wording.

> **Built, as `some-of-it-unsent`, `reconciling`, `the-mac-refused` and `kept-on-this-phone`.** The
> two-devices state is deliberately *not* among them: the design's own answer for it is that the
> sheet says nothing in the footer, because there is no disagreement once the Mac has all seven
> comments — so it would photograph identically to a shipped subject and assert nothing. What it
> does change is a line under the section label, which belongs to the list rather than the footer
> and lands with the count work. The fourth subject here is `kept-on-this-phone` instead: a Mac too
> old to hold a review, which the frames describe and which has no other picture.
- **The Mac's 30 gain a set of four**: default, edited, figures, and a store that refused.

**This screen raises a keyboard on purpose**, and the review sheet's own column baseline was lost
four CI runs to a keyboard inset arriving mid-layout. Drain the harness on both sides of every render
per the `swift-testing` skill.
