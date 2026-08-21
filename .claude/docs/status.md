# Status

Where the project is. Update this when a slice lands.

**Version 0.0.8.** Scaffold complete, CI green, `main` protected, **shipping to TestFlight**.

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

Selecting a Mac still does nothing: the phone has no API client beyond health and no pairing. What
changed is the other end — the Mac now serves the whole read API **over TLS**, under an identity it
generated for itself, and a device pairs with it by scanning a link or typing six words.

## Milestones

The spec's milestones, each ending in something runnable and a green suite, with a review gate.

| | Milestone | State |
|---|---|---|
| M0 | Scaffold — layout, manifest, CI, ruleset, harness, fixtures | **done** |
| — | Delivery — Xcode Cloud archives `main` to TestFlight (iOS) | **done** |
| M1 | Diff parser, display columns, word diff; path grouping into a tree | **done** |
| M2 | Git layer, worktree services, JSON store, session index, HTTP API, CLI | **done** |
| M3 | Menu bar app — settings, Bonjour, pairing, login item, connection log | **in progress** |
| M4 | Phone — pairing with pinning, discovery, worktree list, aliases, pinning | |
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
- **The menu bar app, serving.** It embeds the same backend, advertises under the name the Mac is
  actually called, reports `host:port` in its menu, and opens a Settings window from a status item
  under `LSUIElement` — the trap SPEC §14 asks to be implemented rather than looked up. Its Advanced
  tab is the connection log: the last fifty attempts to reach this Mac, each with the reason it was
  served or turned away, coalesced so one polling phone cannot fill it.
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
- **Pinned trust evaluation against App Transport Security on a real iPhone (M4).** The Mac's half
  is done and proven; what a device has not yet said is whether a `URLSessionDelegate` comparing the
  fingerprint satisfies ATS. `decisions.md` records the constraint M4 inherits: the default
  evaluation must be **replaced**, not added to, because macOS refuses a ten-year certificate
  outright.
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

- **Settings, and it is four more tabs rather than three.** The review gives the connection log its
  own tab and puts Advanced last, so that the panel opened while annoyed is not one mis-click from
  `Reset All Data`. Enabling a project by picking a folder, the visibility toggle, the paired devices
  with revoke, the login item. The store already holds all of it and `PairingInvitations` already
  assembles what the Devices tab draws — the work is the drawing. **The port row is deleted**: a
  service bind hands the port to the system, so General shows the address with a copy button instead.
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
- **Pinning the JSON encoder.** Timestamps are ISO 8601 because that is the framework's default, and
  a test asserts the raw shape so a change is red rather than silent. Setting it deliberately is a
  small job for the next change in the API module.
- **The store's lock file.** SPEC §9 wants one beside the document so a standalone `granita-server`
  and the menu bar app cannot both hold it; today both will happily open the same file. The design
  review declined to draw the held case and said why: **it is a question for Davide, not a designer.**
  Refuse to start, or serve read-only? Advanced is the only surface that could ever say so.
- **The dirty-worktree count** beside the menu bar icon. It needs enabled projects to count, so it
  belongs with the Projects tab. The design draws it, and flags an arithmetic problem first:
  `WorktreeRegistry.projects()` computes a whole change set per worktree — one git process each at a
  ten-second budget — so the number cannot be produced on a tick. **Time it on a real machine before
  building it**: tens of milliseconds means cache and refresh on a slow timer, seconds means the
  count goes behind opening the menu and the label is the icon alone.
- **The Bonjour TXT record.** SPEC §8 wants `apiVersion` and a stable `serverInstanceID` in it so a
  phone can tell its paired Mac from another one. `NWEndpoint.service` carries no TXT record, so
  this needs a way in through the same bind rather than a second `NWListener` — which is the trap
  §8 exists to warn about. The instance identifier is already in the `/v1/pair` response.
- **Revoking a device** has a store method and no route. It belongs with the Devices tab, which is
  the only place that would call it.

## Waiting on Davide

- **A design round trip for the Mac's own surfaces**, which is now the whole of what is left in M3.
  The client's four screens came back on 2026-08-21; the Settings window's four tabs and the pairing
  sheet were not in that ask and have no frames, so none of them can open as a pull request.
- **Pairing from a real device on the LAN**, which is M3's acceptance and cannot be answered from
  this machine — the simulator does not implement local network privacy at all. Until the phone has
  a pairing screen, the way to try it is `make run` with `--pair`: it prints a `granita://pair` link
  and six words every two minutes, and the fingerprint on that line is what the phone must pin.
- **The first design round trip, which only he can start**, and which M4 and M5 are now behind. The
  prompt went over in chat: a review of the discovery screen against its 24 baselines, and a first
  drawing of the worktree sidebar, the file selector and the continuous diff. Until the frames come
  back, no branch touching those screens becomes a pull request — see the `design-handoff` skill.
  What is *not* blocked is everything underneath them: the API client, the view models, the mappers
  and their tests, which no frame can be authoritative about.
- **The refused-permission path, seen on device.** Granting works and is confirmed, and 0.0.4 fixed
  the false refusal Davide hit by backgrounding the app and coming back. What is still unconfirmed on
  hardware is the true one: whether a browser that iOS really is withholding permission from dies
  three times over and reaches the Settings screen within a couple of seconds, rather than sitting on
  "Looking for your Mac". The simulator does not implement local network privacy at all, so only a
  device can say. Turn it off under Settings › Granita › Local Network to check, then turn it back on
  without relaunching — the screen should find the Mac again on its own within five seconds.
- A **second Xcode Cloud workflow for the Mac app**, archiving with Developer ID and notarising.
  Not started; the Mac app runs locally in the meantime, and only distribution needs it.
