# Status

Where the project is. Update this when a slice lands.

**Version 0.0.18.** Scaffold complete, CI green, `main` protected, **shipping to TestFlight**.

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

**Both halves are now designed.** The client's four screens were reviewed and redrawn against 0.0.4
on 2026-08-21 ([`design.md`](design.md)); the Mac's seven surfaces were drawn for the first time on
the same day and are recorded in [`design-mac.md`](design-mac.md). Discovery is the only screen of
the eleven that exists, and it matches its drawing. **Nothing is blocked on a design any more** — the
Mac's tabs are blocked on the snapshot kind the Mac has never had.

Read `design-mac.md` rather than the Mac frames: they were drawn against 0.0.6 and 0.0.7 landed
after, repairing two of the five premises they overturn and making a third obsolete.

The two halves find each other **on real hardware**: the Mac serves `/v1/health` and advertises over
Bonjour, and the phone lists it. Confirmed on Davide's iPhone against his MacBook on 2026-08-19 —
across a wired Mac and a wireless phone, so his network bridges mDNS between the two segments.

Selecting a Mac now says why it cannot connect rather than doing nothing, and pairing is the **only**
thing missing behind it. The phone
has the whole client built and tested behind that tap: it reads a Mac's health, refuses to pair when
the two ends speak different contracts, spends a pairing code, keeps the token in the Keychain, and
reads every route SPEC §8 serves. What it has no way to start is the camera — the QR scanner and the
pairing screen have no frames, and the `design-handoff` rule forbids a pull request touching a screen
that has none.

**So the client is wired up to the seam rather than into the app.** The composition root builds the
browse and nothing else; `MacPairing` is composed by the pull request that draws the screen calling
it. That is deliberate: a dependency wired into a root that no screen can reach is code nothing can
be measured against, which is what the coverage gate said in as many words.

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
| M5 | Phone — file selector, continuous scroll, highlighting, word diff, viewed state | |
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
- **The git client**: the closed set of questions the product asks git, the argument vector each one
  becomes, and the process that runs it — both streams drained at once, a byte cap that truncates
  rather than refuses, a ten-second budget that tears the process down without ever signalling a
  process group, and failures that carry git's own standard error. Every invocation is pinned
  against a developer's git configuration, and a fixture repository configured to defeat it proves
  that rather than leaving it asserted.
- **The whole server.** Worktree enumeration, the change set and its stats from one comparison,
  per-file diffs with the size guards, §5.5 content hashing, the JSON store, the Claude Code session
  index, and every §8 route behind bearer auth. `granita-server --add-project <path>` enables a
  repository and `--insecure-http` serves it; the phone cannot read any of it yet.
- Six gating CI jobs on a pinned Xcode 26.6 / macOS 26 runner. 591 package tests in 64 suites, plus
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
  iPad. §2–§4 are drawn and waiting for M4 and M5.
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
- **One model for the client's connection unit**, replacing the discovery view model. Nothing in the
  client is named `…ViewModel` any more. Joining a Mac is a **use case** in `Domain` rather than a
  method on the model, and the model carries only the browse: the pairing surface lands with the
  screen that reads it, because a property no screen has agreed to is a property nothing can be
  measured against. `MacPairing.alreadyPaired()` is what the discovery list's *Recent* and *Other
  Macs* sections will be ordered by, once the Mac's Bonjour TXT record carries the instance
  identifier that joins a discovered Mac to a stored token.
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
- Character-wrapping height arithmetic against measured heights (M5).
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
- **The Bonjour TXT record**, which now blocks something concrete. SPEC §8 wants `apiVersion` and a
  stable `serverInstanceID` in it so a phone can tell its paired Mac from another one.
  `NWEndpoint.service` carries no TXT record, so this needs a way in through the same bind rather
  than a second `NWListener` — which is the trap §8 exists to warn about. The instance identifier is
  already in the `/v1/pair` response, and the phone now holds a token against it: what is missing is
  the **join**, because a discovered Mac is only a Bonjour instance name. Until the record carries
  it, design §1's *Recent* and *Other Macs* sections cannot be built and the list ships as the single
  unlabelled section that section says it degrades to.
- ~~**Revoking a device** has a store method and no route.~~ Built with the Devices tab in 0.0.15,
  and its refusal is drawn: a Revoke that leaves the row where it was is a control that did nothing,
  on the one tab where doing nothing means a phone can still read this Mac.

## Waiting on Davide

- **The Accessibility grant, under System Settings › Privacy & Security › Accessibility.** It is the
  last thing between `make ui-tests-mac` and a green run, and it is now blocking **ten** shipped
  controls rather than a target: the Devices tab's `Revoke`, `New Code` and `Open General`, the
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
  this machine — the simulator does not implement local network privacy at all. Until the phone has
  a pairing screen, the way to try it is `make run` with `--pair`: it prints a `granita://pair` link
  and six words every two minutes, and the fingerprint on that line is what the phone must pin.
- **A design for the QR scanner and the pairing screen**, which is now the only thing between the
  phone and a paired Mac. Everything behind that screen is built and tested; what has no frames is
  the viewfinder, the six-word fallback field, and what a reader sees while a code is being spent
  and when it is refused. The client round trip of 2026-08-21 did not include them. Until they come
  back, no branch touching those screens becomes a pull request — see the `design-handoff` skill.
- **The refused-permission path, seen on device.** Granting works and is confirmed, and 0.0.4 fixed
  the false refusal Davide hit by backgrounding the app and coming back. What is still unconfirmed on
  hardware is the true one: whether a browser that iOS really is withholding permission from dies
  three times over and reaches the Settings screen within a couple of seconds, rather than sitting on
  "Looking for your Mac". The simulator does not implement local network privacy at all, so only a
  device can say. Turn it off under Settings › Granita › Local Network to check, then turn it back on
  without relaunching — the screen should find the Mac again on its own within five seconds.
- A **second Xcode Cloud workflow for the Mac app**, archiving with Developer ID and notarising.
  Not started; the Mac app runs locally in the meantime, and only distribution needs it.
