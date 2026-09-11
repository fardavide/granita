# Design — the Mac

The menu bar app's seven surfaces, drawn for the first time. This is the authority on **what the Mac
looks like and why**; [`design.md`](design.md) is the same thing for the phone and the iPad.

The drawings were working material and did not last. `design/granita-mac-design-review.html` held
the frames at 1:1, each section deleted from it as it was implemented; **§1 and §2 were the last two
and the file went with them in 0.0.16**, which is what it said would happen. Every measurement worth
keeping is in this document — the window's 620 × 560pt and where that number comes from, the QR's
module range, the five premises and both open calls — and this prose does not expire, because it
keeps each call beside the alternative it beat.

First drawing, 21 August 2026, against 0.0.6. The Settings window was drawn at 620 × 560pt and the
status item at its real 22pt height. Everything is a stock control: `TabView`, `Form`, `List`,
`Toggle`, semantic colours, SF Symbols. Where the review moves something it names the control it
becomes.

> **Read the next section before building anything.** The review was drawn against 0.0.6 and 0.0.7
> landed after it. Two of the five premises it overturns were fixed in that release, independently
> and before the frames came back, and a third is obsolete. Building the drawing as returned would
> reintroduce a warning that is no longer true.

## What is settled, and what is still open

| Section | Surface | State |
|---|---|---|
| §1 | The status item and its menu | **built in 0.0.16**, with baselines. Frames deleted. Three symbols and no count; the status line copies, and the pane is applied to the model rather than carried on `settingsRequests` — below |
| §2 | The window — five tabs | **complete as of 0.0.16.** Five tabs since 0.0.15, fixed at 620 × 560pt with Advanced last; the last-used pane is restored across launches and a first run opens Projects. Frames deleted |
| §3 | General | **built in 0.0.10**, with its baselines. Frames deleted |
| §4 | Projects | **built in 0.0.14**, with baselines. Frames deleted. Two departures, both below: the second figure is filled in progressively, and the scan follows the specification's skip list rather than the sheet's own drawing |
| §5 | Devices | **its drawn half built in 0.0.15**, with fourteen baselines. Frames deleted. The six words grew a Copy button in 0.3.1, which the frames do not draw — below. The Allow-from-the-Mac path is still out: no frames and no protocol |
| §6 | Connections | **its own tab and relaid out in 0.0.11**; the `Pair…` affordance landed in 0.0.15 with the tab it opens. Frames deleted |
| §7 | Advanced | **built in 0.0.11**, with baselines, minus its Diagnostics half — the verbose switch and Open in Console describe logging this product does not have, and land with it. The lock-file row waits on the lock file |

Two things the review could not decide from drawings. **Both are now answered**, on 22 August 2026,
and the answers are below rather than in the review because neither came from a drawing.

| | Question | Answer |
|---|---|---|
| a | Is the dirty-worktree count in the menu bar affordable? | **No — by two orders of magnitude.** Measured, not estimated: 122.7 seconds. Neither branch the review drew survives, so the label is **the icon alone** and the count is not built |
| b | What happens when the store's lock file is already held? | **Refuse to start, and say which process holds it.** Not read-only |

**The measurement, because the number is the whole answer.** `/v1/projects` was served from a store
holding ten of Davide's real repositories — 38 worktrees, one Android monorepo carrying 16 of them —
and answered in **122.7 seconds**. The review's two branches were "tens of milliseconds: cache and
refresh on a slow timer" and "seconds: put the number behind opening the menu". Two minutes is
neither: a menu that computes this on open is a menu that does not open, and a cache refreshed on a
slow timer would keep 38 git processes running for two minutes out of every period.

So the count is **not built**, and the reason is arithmetic rather than taste. What would make it
affordable is a different question asked of git: `projects()` computes a *whole change set* per
worktree — every changed path, its stats and its revision — in order to test one boolean. Git can
answer "is anything different here" without producing any of that. Until something asks the cheap
question, the menu bar is one symbol and no `Text`, and SPEC §9's `Text("\(n)")` beside the icon is
deferred rather than dropped — the TRAP it exists to satisfy is still true, and still costs nothing
to honour on the day there is a number to draw.

**Refusing to start is the answer to (b), and Advanced is where it is said.** The alternative was
serving read-only, which sounds accommodating and is worse: two processes would disagree about what
is enabled, and the phone would read one of them without either the phone or the reader being told
which. A refusal names the process holding the lock, because "another Granita is running" is not
actionable and a process identifier is.

## The five premises, and which of them are still true

The review measured five of the specification's premises against the code before drawing anything.
Two were repaired by 0.0.7 in the same week, which is recorded in [`decisions.md`](decisions.md)
under the entries on the six words and on the `Host` header.

| | Premise | Verdict |
|---|---|---|
| 1 | The connection log's source is `request.head.authority` — this Mac, on every row, and the rate limiter shares the key | **Already fixed.** `GranitaRequestContext` carries the peer address off the channel and `source` is the address without its port. The global lockout the review warned about cannot happen |
| 2 | Port 8737, automatic fallback, chosen port persisted | **Stands.** A `.bonjourService` bind hands the port to the system — four recorded runs took 59144, 59145, 53613, 53611. All three clauses describe the CLI, not this app |
| 3 | The escape hatch is on, so warn about it | **Stands, but its replacement is obsolete.** The banner goes, because `MacComposition` hard-codes `requiresAuthentication: true` and a banner for an unreachable state is always wrong. The review moved a *plaintext* warning under the QR instead — **do not build that**: TLS and a real `spki=` landed in 0.0.7, so the link is encrypted and pinnable |
| 4 | The six words are a decoration, and two of them need changing | **Already fixed**, and the word list was worse than the review saw. The words are an independently random second credential redeeming the same pairing. The review caught `amber`/`ember`; a property test over all pairs also caught `bacon`/`beacon`, now `emerald` and `beetle` |
| 5 | Device rows carry last-seen times | **Stands.** `StoredDevice` holds `pairedAt` and nothing later, so last-seen exists only for the current run of the server |

## §1 — The status item

Six specified states, **three symbols**, and a count that appears in exactly one of them.

- Serving is `arrow.trianglehead.branch`. Starting is `hourglass`. **Not** serving is one symbol for
  both failure and stop — `exclamationmark.triangle`, unfilled. The menu bar answers one question,
  which is whether the phone can read this Mac; the reason is one click below.
- The count is a `Text` beside the image with tabular figures, drawn **only while serving and only
  above zero** — **and it is not built**, because producing the number costs 122.7 seconds. See
  answer (a) above. What ships is the symbol alone, which is what the drawing's own third state
  shows anyway.

**Rejected: the zero.** A menu bar is shared, permanent and glanced at, and "0" is a claim the reader
parses and dismisses every time they look at the clock — while saying exactly what the icon alone
already says. Also rejected: a badge modifier, which SPEC §14's TRAP forbids; a coloured dot, since a
status item image is template-tinted by the system and cannot be relied on to stay red; and
`pause.circle` for stopped, which offers a play button this app does not have. The server's life is
the app's life, so "stopped" here means it fell over.

Should feel like the Time Machine menu — a glance tells you it is fine, and you open it twice a year.

### The menu

**Keep "Pair a device…", and make it a door rather than a duplicate.** It opens Settings *on the
Devices tab*: there is one QR in the app and this is a second door to it, not a second
implementation. It earns the row because under `LSUIElement` this menu is the entire app, and a
person holding a phone has nowhere else to look. Two consequences: it is **disabled when the server
is not running**, since the QR encodes a host and port that do not exist; and `settingsRequests` has
to carry *which tab* was asked for rather than being a bare counter — a value on the request that
already goes through `SettingsOpener`, not a new mechanism.

**The status line becomes a `Button` that copies.** It is a `Text` today, which the code correctly
calls "present, legible and unclickable". The port differs every launch, so nobody memorises it and
the only reason to read it is to paste it — make the row copy `http://macbook-pro.local:59144` and
the fact becomes a tool. The drawing puts the count's noun on the line underneath, because a bare
"3" in the menu bar cannot carry one; with the count deferred that second line has nothing to say
and is not built either.

When the server has failed, the menu leads with the refusal and the one thing to do about it —
*Not serving — macOS is blocking the local network*, then **Open Local Network Settings…**.

Rejected: dropping the item and letting Settings be the only route, which saves one row and costs the
one gesture a new device needs; a separate "Copy address" item, which is two rows for one fact; and
putting the local-network fix behind an alert, when the menu is where the reader already is.

### Five calls made while building it

**What the status line copies has no scheme.** The drawing shows `http://macbook-pro.local:59144`,
and it was drawn against 0.0.6 — TLS landed in 0.0.7. `https://` is now the truthful spelling and it
is the wrong thing to hand a reader: pasted into a browser it produces a certificate warning under a
self-signed identity, which is the opposite of what this row is for. General had already settled on
host and port alone for exactly that reason, and two rows copying one fact must not spell it two
ways. What is copied is what General copies, through the same call.

**The copy announces itself before it happens**, with General's own `doc.on.doc` beside the address.
A menu closes on click, so a row whose entire effect is a changed pasteboard has no way to report
itself afterwards — and a control a reader cannot perceive the result of is the defect this project
cares most about. Borrowing the icon rather than inventing one means the affordance is already
familiar from the tab that has it.

**The refusal names no cause.** The drawing writes *Not serving — macOS is blocking the local
network*; the menu says **Not serving** and offers **Open Local Network Settings…** underneath.
`failed` carries whatever went wrong and a locked keychain reaches it too, and a menu has no room for
the small print that lets General name a likely cause without asserting it. §1's own argument settles
this: the menu bar answers one question and *the reason is one click below*. The button still ships,
because Local Network is the overwhelmingly common cause and offering the fix is not the same as
claiming the diagnosis.

**Stopped gets the refusal and no button.** Local Network is no way at all to reach that state — the
server's life is the app's life, so stopped means it fell over — and a button that fixes a different
problem is a control doing nothing.

***Pair a device…* is enabled while starting**, which departs from "disabled when the server is not
running". A bind takes a moment and a rebind after waking takes longer; the Devices pane already
draws that moment as a code being made, deliberately, so that a reader with a phone in their hand is
not sent to General to fix something that is already happening. Disabling a row for a state that
resolves itself in under a second would fight them at the same moment for the same reason. Failed and
stopped stay disabled, and the *Not serving* line directly above is what says why.

**The pane is applied to the model rather than carried on `settingsRequests`.** The review expected
the request to carry it, and so did `decisions.md`, but both were written before `ServerMacModel`
owned the selection. A pane riding on the request would be a second copy of a fact the model already
holds — and `SettingsOpener` watches that value with `onChange`, which cannot tell "asked for Devices
again" from "nothing happened", so a reader who moved to Advanced and pressed the row a second time
would meet a menu item that did nothing. `requestSettings(showing:)` carries the pane, sets it, and
then asks for the window, in that order.

## §2 — The window

**Five tabs, not four, and Advanced last: General, Projects, Devices, Connections, Advanced.** This
disagrees with the specification twice.

The connection log is **not** an advanced setting. It is a live view of what is happening to this
Mac, the only panel with a reason to be reopened, and the one thing here read under pressure. It gets
its own tab. Advanced goes last because that is where every Mac app puts it, and because of what
shares that tab: `Reset All Data`. Leaving the log there means the panel opened while annoyed is one
mis-click from the button that unpairs every device.

**Order and selection are different decisions.** Advanced is first in the code today for a good
reason — it was the only tab worth opening — and that reason expires the moment General and Projects
exist. Order as above, restore the last-used tab after that, and select **Projects** on a first run,
because until something is switched on the app does nothing at all.

**Both halves of that are one question, and the answer is an optional.** A remembered pane and a
first run are the same seam seen from either end, so the memory answers with a pane *or nothing* and
the model decides that nothing means Projects — rather than the memory defaulting and the caller
never learning which of the two it got. It lives in this app's user defaults and not in the JSON
document: that file is shared with `granita-server`, which has no window and no panes, and a
preference belonging to one of two processes does not belong in the file they both hold. The pane
names are spelled out rather than derived from the case names, because a rename would otherwise send
a reader back to a pane they were not on, silently and only on machines that had already stored the
old word. Losing it costs nothing — a reader whose defaults did not travel to a new Mac lands on
Projects, which is what a first run does anyway.

Tab symbols: `gearshape`, `folder`, `iphone`, `point.3.connected.trianglepath.dotted`, `gearshape.2`.

**The window is 620 × 560pt, fixed width.** The height comes from the QR: the pairing payload is
about 140 bytes once the digest is percent-encoded, which in byte mode at error correction M is QR
version 8 or 9 — 49 to 53 modules. At the 4pt module that scans from arm's length, plus a
four-module quiet zone, **the QR is 236–244pt square**. Stacked with the fallback words, the
countdown and two paired devices, Devices needs 560pt. The code's `minHeight: 400` would make a
person scroll to a QR while holding a phone up to it.

Rejected: a System Settings sidebar, which is a bigger window for five one-word panes; and letting
the window resize per tab, because between a 560pt QR pane and a three-row General pane the jump
reads as a glitch.

Should feel like Terminal's Settings — five plain panes, opened rarely, none of them clever.

## §3 — General

Three rows, and two of the specification's four are gone.

**There is no port to set.** The row becomes what a person actually wants from it: the address in
monospace with a **copy button**, and a footnote saying who chose it — *macOS chooses the port when
Granita advertises itself, so it changes every launch. Your phone finds this Mac by name, not by
port.* The one real use for that string is pasting it into `curl`.

Rejected: a disabled Port field with an explanation, since a control you cannot operate is worse than
a fact you can read; and a Port field that *works* by switching the binding to `.hostname`, which
buys a memorable number and pays for it with Bonjour — the only way the phone finds this Mac at all.
If a fixed advertised port is ever genuinely wanted it is a change to the binding, not a control on
this tab.

**There is no escape hatch to warn about**, per premise 3 above.

**Startup** is one `Toggle` — *Open Granita at login* — with the footnote *Granita has no window and
no Dock icon. If it is not running, your phone finds nothing.* When `SMAppService.register()` is
refused, the toggle goes back to off and says why, offering **Open Login Items…**.

**The failure state follows the phone's rule exactly: our sentence, our button, the system's string
demoted to small print.** A refused Bonjour registration is the failure this app is most likely to
hit on a machine that has never run it, and `ServerRunState.failed` already carries the reason. The
button opens Privacy & Security › Local Network directly; without it an `NWError` code is the whole
explanation a person gets for an app that does nothing.

### Two calls made while building it, both departures from the drawing

**The failure sentence names the likely cause rather than asserting it.** The frame reads *macOS is
not letting Granita on the local network*, which is true of the failure this state is most often
reached by and false of the others — `failed` carries whatever went wrong, and a locked login
keychain reaches it too. A screen that says the local network is blocked over a keychain error sends
the reader to a settings pane that is already correct, which is worse than vagueness. What ships is
*Your phone cannot find this Mac. The usual cause is Local Network access being turned off for
Granita.* — our voice, the same button, and the system's own string underneath doing the
distinguishing.

**The address carries no scheme, which is the frame's own answer and worth stating.** It reads
`macbook-pro.local:59144`. A scheme would have to be `https` now that the Mac serves TLS under a
self-signed identity, and pasting that into a browser produces a certificate warning rather than an
answer. Note for §1: the menu's copy is drawn as `http://macbook-pro.local:59144`, which was true of
0.0.6 and is not now — that row is built with the rest of §1 and the scheme is a decision it has to
make rather than inherit.

**A third call, made in 0.0.18: one non-serving state does not use that sentence at all.** The
paragraph above hedges *the usual cause* precisely because `failed` carries whatever went wrong — but
hedging is not enough when the cause is known and is something else entirely. A store lock held by
another process reaches this tab too, and there Local Network access is not merely unlikely, it is a
pane that is already correct: a reader who follows the button finds nothing to change and comes back
knowing less. So that refusal is a **run state of its own**, and this tab leads with its own sentence,
names the process holding the settings, and offers **Quit Granita** — which the app needs anyway,
having no Dock icon and no window whose red button ends it.

Should feel like the Sharing pane.

## §4 — Projects

The security boundary. **Two verbs, kept apart:** adding a repository puts it in this list, and a
switch decides whether the phone can see it. A scan can only ever do the first.

**The scan's results never enter this list uninvited.** A scan opens a **sheet**, and its results
stay there until they are chosen. What the sheet writes is "added, switched off"; the switch in the
list is a second, separate act. That is what makes "thirty found, none enabled" read as deliberate —
thirty things were *found*, and the tab never grew by thirty rows, so there is nothing to mistake for
a broken import. **There is no Select All**, which would be the one gesture making thirty
repositories of private source code addable in a click. The confirm button counts what it will do —
`Add 2 Repositories`, disabled at zero.

Rejected: listing candidates inline as disabled rows, which turns the security list into a set of
things you must check you have *not* switched on; enabling straight from the sheet; and a "scanned"
section in the tab, which gives the list two meanings and makes the toggle's blast radius depend on
which section a row is in.

**The row, in order: switch, name, path, then what it costs.** The switch is first because it is the
only thing on the row with consequences, and left is where a Mac reader's eye starts. The path is
monospaced and secondary because two projects can share a name and only the path settles it. The
trailing figure — `4 worktrees, 2 with changes` — comes from `Project.worktreeCount` and
`dirtyWorktreeCount`, which already exist, and it is what reconciles this tab with the menu bar
count.

**A project whose folder has gone says so.** Today it still passes `isVisible`, so `projects()`
serves it with zero worktrees — indistinguishable on the phone from a project with nothing to read.
The row says *Folder not found*, **disables** the switch, keeps the last known path in monospace and
offers `Locate…`. Disabled rather than silently flipped off, because turning off something a person
turned on is a decision the app should not make while they are not looking.

The empty state is a `ContentUnavailableView` with `folder.badge.plus`, offering both verbs once.

Should feel like Full Disk Access in Privacy & Security.

### Three calls made while building it

**`2 with changes` is filled in after the row rather than drawn with it**, and that is Davide's call
of 23 August 2026 rather than a shortcut. The review says the figure "comes from
`Project.worktreeCount` and `dirtyWorktreeCount`, which already exist" — they do, and the second one
had not been timed. It is the same question that costs 122.7 seconds across ten repositories, and
even asked the cheap way it is 16.7 seconds for one Android monorepo's sixteen worktrees against
0.014 for the worktree count. So the tab draws the list from what is cheap and walks the visible
projects afterwards, each answer landing in its own row. The second line reads `checking…` in the
meantime — drawn rather than absent, because a row that grows by a line when an answer lands moves
every row below it on a list a reader is aiming a switch at. The alternative it beat was dropping the
line; the reason it lost is that the worktree count says how much is behind a switch and only this
line says whether there is anything to read. See [`decisions.md`](decisions.md).

**The scan skips `vendor`, so the sheet's own `vendor/swift-nio` row can never appear.** SPEC §9
names six directories and the frames draw a candidate inside one of them. Put to Davide on 23 August
2026 and settled toward the specification — the row reads as an illustration of a nested path, which
the sheet needed an example of. Three further limits are ours and are in `decisions.md`: hidden
directories wholesale, four levels of depth, and a candidate being a `.git` **directory** rather than
the `.git` file a linked worktree has.

**Two states the frames do not draw, and both had to exist.** A scan that is still looking, because
a development folder is fast and a home directory is not and finding that out with a frozen sheet is
the wrong way; and a scan that found nothing new, where the confirm button is **absent** rather than
permanently grey. There is also a failure line under the list — our sentence with the store's own
words beneath it — for the case the frames assume away: every control on this tab writes to the
store, and a switch that springs back in silence is a control that did nothing.

## §5 — Devices

The QR is the largest thing in the app and it sets the window's size.

**Paired devices** lead with the fact that is real — *iOS · paired 3 August* — and add *Seen 4 min
ago* only when this run has actually served that device. A device with no sighting says *Not seen
since 9:12*, which is true, rather than a stale date that reads as an accusation. Each row has a
destructive **Revoke**.

Rejected: persisting last-seen properly. `JsonDocumentStore` rewrites the whole document and its
contract is "written rarely, read on every request", so a polling phone would turn every request into
a disk write. If it is ever wanted it is a coarse daily stamp written on change.

**The six words sit at 13pt monospace directly under the QR, as an equal, not as small print** —
they are a second credential redeeming the same pairing, not a caption. Under them, the countdown:
*Expires in 1:46*, *Single use*, on a `ProgressView`.

**Do not build the plaintext warning the frames show under the QR.** It was true of 0.0.6 and is not
true now.

### The QR was re-opened on 22 August and closed again, and one thing was added

Davide asked for the QR to go, on the grounds that the connection mechanism as it stands is already
right, and then reversed it in the same exchange once it was clear the picture *is* the mechanism's
one-gesture path rather than decoration. **The QR stays exactly as drawn.** Recorded because a call
that was re-opened and settled the same way is worth one line, so it is not re-opened a third time.

What the exchange did add is a requirement the review never saw, and it comes from a real failure
he has hit: **a device must be approvable from the Mac, without anything reading the code.** The
case is remote control — he is on Screens looking at the Mac *from the phone he is trying to pair*,
so the camera and the screen are the same device and the QR is unscannable. Today the only way out
is a second device, a screenshot, and a lot of annoyance.

So Devices grows an **Allow** affordance beside the devices it can see, and that is a surface with
**no frames and no protocol**. Both halves are missing, not just the drawing:

- Nothing on this Mac knows a phone exists until that phone presents a credential, so "the devices
  on the net" is not a list anything can currently produce. Some announcement has to exist before
  something can be allowed, and inventing one is a change to SPEC §8 rather than a layout.
- The review drew a QR, a countdown and paired rows. It did not draw a pending device, what it says
  before it is allowed, or what Allow does to it.

**§5 therefore ships in two pieces.** The QR, the six words, the countdown and the paired rows with
Revoke are drawn and are buildable now. The Allow path is a design round trip and a protocol
question, and under the `design-handoff` rule no pull request touches it until its frames exist.

Two other states are drawn: **expired**, where the QR dims behind *Code expired* / *A code lasts two
minutes and works once* and a **New Code** button; and **server not running**, which shows no QR at
all — *Pairing needs the server* / *A code has to say where to reach this Mac, and nothing is
serving*, with **Open General**.

Rejected: a ring or gauge for the countdown, which invents a control; and no countdown at all, which
leaves the worst state undrawn — a code that quietly expired looks exactly like a wrong code from the
phone's side.

Should feel like the four-digit code an Apple TV puts on the television.

### Three calls made while building it

**Two states the frames do not draw, and both had to exist.** A code that could not be made — the
link is signed by an identity out of the login Keychain, which can be locked — gets our sentence with
the Keychain's own words beneath it and a **Try Again**; and a code that is *being* made, which is the
honest state before the first one lands rather than a placeholder for something unbuilt. See
[`decisions.md`](decisions.md).

**The pane fits the 560pt window, and only after the stack was tightened.** The first render put the
countdown below the fold — the one part of this pane a reader is watching. Ten points of spacing
between each of five children was the whole difference, and the next line added here will cost the
same again.

**The words are drawn with a separator the server accepts back.** The frames separate them with a
middle dot; `SpokenWords.normalised` split on spaces and hyphens only, so a reader who selected the
line and pasted it would have been refused for the punctuation this tab chose. Also
[`decisions.md`](decisions.md).

### The words got a Copy button, which the frames do not draw *(26 August 2026)*

The call above finishes half a sentence: the separator was chosen so that **a reader who selects this
line and pastes it** is not refused, which means selecting and pasting is the flow this tab was
already designed around. It just left the reader to drag a selection across six words in a 13pt
monospaced line to start it. A button is one gesture for the same thing, and this app already has the
shape for it — General's address row and the menu bar's status line, `doc.on.doc`, borderless, with
the label going to `help` and the accessibility label.

**It is on the same line as the words, and that is this section's own measurement rather than a
preference.** The paragraph above records that the pane fits the 560pt window only after the stack
was tightened, and that the next *line* added here puts the countdown below the fold — the one part
of the pane a reader is watching. A trailing button costs no height at all.

**What it copies is the line as drawn**, middle dots and all, because that is the form the phone
accepts back. The drawn spelling and the separator now live in `SpokenWords` beside the normaliser
that accepts them, so the tab's choice and the phone's tolerance are one fact — and the round trip is
asserted rather than described.

> Rejected: copying the hyphenated wire form. It is what the Mac stores and it is *not* what the
> reader is looking at, and this tab has already decided once that the line on screen and the line a
> phone receives must be the same line. Rejected: a Copy under the words, which is the line this
> section says costs the countdown.

**It does not solve the same-device case**, and should not be read as doing so. A reader on Screens
is looking at this Mac *from* the phone being paired, and the two have different clipboards. That is
still the Allow path, which has no frames and no protocol.

## §6 — Connections

The one surface that exists. The shape is right and the empty state is the best copy in the app.
Since premise 1 is already fixed, what remains here is **layout**, not the value behind it.

**A refusal that can be acted on says so.** A served row is a receipt; a refused row is a to-do, and
it gets the one affordance the served row does not — `Pair…` for no token, `Pair Again…` for a token
this Mac did not issue. Version skew and rate limiting get no button, because there is nothing on
this Mac to press. Same list, same order, one axis of difference that means something. Built in
0.0.15 with the tab it opens: inside the window that is a **tab switch**, and which pane is up is the
model's rather than the window's, so a control whose whole job is to move a reader somewhere is a
thing a test can ask about.

**Two edits to what the row says.** Drop the word "Refused" — the `xmark.circle` already says it,
forty-five times down a list, and the space pays for the address and the count. And **print the
repeat count**: the coalescing is right, but as built it turns four hundred attempts into a row that
looks like one, and "my phone tried once" against "my phone has been hammering this for ten minutes"
are different problems.

The footer reads *Since 9:12 · the last 50 attempts, this run only*, with a count.

**The since-time is the oldest row's, not the moment the server started.** The two are the same until
fifty attempts have been recorded and stop being the same afterwards, and of the pair only the oldest
row truthfully answers how far back what is on screen goes.

**The rate-limited row counts attempts like every other refusal**, rather than the frame's *blocked
for 41 sec*. Nothing records how long a lockout has left — the refusal carries no deadline — and a
duration stamped at the moment of refusal is a lie by the time anyone reads it, which is the same
defect this section's own time column was just repaired for.

**And the elapsed time is handed to the row rather than derived by it**, which is what let this panel
have baselines beyond its empty state at all. See [`decisions.md`](decisions.md).

Rejected: colour as the difference, since during setup nearly every row is a refusal and a wall of
red stops being a signal; sections or a filter picker, because this log is read once, in anger, and
sorting destroys the newest-first order that makes it readable; and a `Table` with sortable columns,
which is a database inspector for fifty rows held in memory.

**Kept exactly as written:** the empty state. *"Nothing has tried to connect"*, with *"every device
that reaches this Mac appears here, whether or not it gets in"* — it tells you the panel is working
when it is showing you nothing.

Should feel like Console, if Console only ever answered one question.

## §7 — Advanced

Four rows once the log moves out, in two sections. Two of them are one-way doors, so the tab's whole
job is to make the difference obvious.

**A verbose switch, not a log level.** Five syslog levels are a vocabulary for someone reading
someone else's logs; there is one reader here and he wants either the normal amount or all of it.
Beside it, **Open in Console**, filtered to Granita's subsystem — and the button matters more than
the switch, because a level control with no route to the log leaves a person choosing how much of
something they cannot find.

> **Both are built as of 0.0.18**, one release after the logging they describe. The filter reaches
> Console **on the pasteboard**, as this sheet settled in advance: `Console.app` registers no URL
> scheme and cannot be handed a predicate, so pressing the button copies the filter and opens the
> window, and the section footer says to paste — a Console window that opens unfiltered is a button
> that appears to have done nothing. What the switch turns on is what the footnote promises, and the
> footer also says what it cannot turn **off**: refusals and failures are written either way.

**git gets a version, not just a path.** `GitExecutablePath` picks the first of three candidates that
is executable, and the interesting question is never which won but whether the one that won works.
The row reads `2.52.0` first and the path second, and in failure it carries git's own standard
error — the rule the whole API already follows.

**Reset states its blast radius, using the store.** The row above the button counts what exists — two
projects, two devices — and the confirm repeats it in consequences rather than nouns: *they have to
pair again*. That sentence is not decoration; a reset is precisely why the log later says "that token
was not issued by this Mac".

**And the lock file, when it is already held.** Answer (b) above is *refuse to start*, so this tab is
where the refusal is read: the row names the process holding the lock rather than saying another
Granita is running, because a process identifier can be acted on and a noun cannot. It is the only
row here that describes a state in which the rest of the app is doing nothing.

> **Built in 0.0.18, and it turned out not to be only this tab.** The row is here as drawn — drawn
> only when it is true, and on *is blocked* rather than on *has a holder*, so it does not vanish in
> the case where the lock file could not be read and a reader has least to go on. What the sheet did
> not anticipate is that the refusal also needed **§3**: Advanced is the tab a reader reaches last,
> and a Mac that is not serving is a question they ask on General first. So the refusal is a run
> state of its own, and General leads with it, names the process and offers **Quit Granita** rather
> than the *Open Local Network Settings* that every other non-serving state offers — that pane is
> already correct for a lock conflict, and sending a reader to it costs them a trip.

Rejected: a five-level picker; a "Reveal in Finder" row for the log as well as the data folder, when
the log's home is Console; and a second confirm typed by hand, which is disproportionate for one
developer's own machine.

Should feel like Xcode's Advanced pane.

## What the Mac still has no way to check

Every surface above is code that **nothing renders**: the snapshot suite is the iOS target, and the
Mac has no snapshot kind at all. The frames are drawn at 1:1 precisely so they can become the
baselines, and the review is explicit that the window's real minimum has to be asserted from inside
the app — window geometry is not measurable from outside while Stage Manager is on.

So the macOS snapshot kind lands in the same pull request as the first tab built from a frame. That
is not a preference: without it, "we built the design" is an assertion nobody can check.
