# Status

Where the project is. Update this when a slice lands.

**Version 0.0.14.** Scaffold complete, CI green, `main` protected, **shipping to TestFlight**.

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
destroy before it does. **Its Diagnostics half is deliberately absent**: the verbose switch and *Open
in Console* describe logging that **does not exist anywhere in this product**, so both land with a
logging layer rather than as controls over nothing. The lock-file row waits on the lock file.

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
- Six gating CI jobs on a pinned Xcode 26.6 / macOS 26 runner. 361 package tests in 38 suites, plus
  the snapshot suite on a simulator.
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
- **The menu bar app, serving.** It embeds the same backend, advertises under the name the Mac is
  actually called, reports `host:port` in its menu, and opens a Settings window from a status item
  under `LSUIElement` — the trap SPEC §14 asks to be implemented rather than looked up.
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

What is left is **screens, and their frames have now arrived.** The Mac round trip came back on
2026-08-21 and its calls are recorded in [`design-mac.md`](design-mac.md), so nothing here is blocked
on a design any more:

- **Settings, and one tab is left.** General, Projects, Connections and Advanced are built;
  **Devices is not.** The paired devices with revoke and the QR. `PairingInvitations` already
  assembles what that tab draws — the work is the drawing. §5's Allow-from-the-Mac path stays out
  until its frames exist.
- **A logging layer, which nothing has needed until now.** Advanced's verbose switch and its route
  into Console are the first thing that does, and both are blocked on it. The Console filter travels
  **on the pasteboard**, because `Console.app` registers no URL scheme and cannot be handed a
  predicate; that is settled and recorded.
- **The pairing QR.** The link and the six words exist and are exercised through
  `granita-server --pair`; what is missing is the picture of one. It is the largest thing in the app
  at 236–244pt square, and it is what sets the window to 620 × 560pt.

**Read `design-mac.md` rather than the frames.** They were drawn against 0.0.6 and 0.0.7 landed
after, repairing two of the five premises they overturn and making a third obsolete — the sheet says
which still stand.

**Owed before any of them: a macOS snapshot kind**, unchanged from below, and now the only thing
between M3 and done.

**The milestone's acceptance — pairing from a real device on the LAN — is the one thing left that
this machine cannot answer**, and it is what earns the minor version. Everything it depends on is
proven from a terminal; see "Verified against the real environment".

**Owed before slice 2: a macOS snapshot kind.** The Mac's views are measured by no test kind at all
— the snapshot suite is the iOS target — so every screen the Settings window gains is code nothing
renders. The gate tolerates that today because the Unit and All rows were rescoped in the same pull
request that created the gap, and a rescoped row is unjudged for one run. It will not tolerate the
four remaining tabs. The frames have come back drawn at 1:1 precisely so they can become the
baselines, and a screen built from a frame lands with its baselines: that is the pull request the
macOS kind belongs in. The review adds a second reason — the window's real minimum can only be
asserted from inside the app, because window geometry is not measurable from outside while Stage
Manager is on.

Smaller things still open in these modules:

- **The `xcrun -f git` step.** Both composition roots now share one probe of three fixed paths;
  `xcrun` is itself a subprocess and still wants its own seam.
- ~~**Pinning the JSON encoder.**~~ Done. Both the request context and the phone's decoder now say
  `.iso8601` in as many words, so a dependency changing its default moves neither end silently.
- **The store's lock file.** SPEC §9 wants one beside the document so a standalone `granita-server`
  and the menu bar app cannot both hold it; today both will happily open the same file. **Answered by
  Davide on 2026-08-22: the second one to start refuses, and names the process holding the lock.**
  Not read-only — two processes disagreeing about what is enabled, with the phone reading one of them
  and nobody told which, is worse than a refusal. Advanced is where the refusal is read. Still to
  build.
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
- **Revoking a device** has a store method and no route. It belongs with the Devices tab, which is
  the only place that would call it.

## Waiting on Davide

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
