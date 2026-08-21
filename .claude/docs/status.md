# Status

Where the project is. Update this when a slice lands.

**Version 0.0.4.** Scaffold complete, CI green, `main` protected, **shipping to TestFlight**.

The two halves find each other **on real hardware**: the Mac serves `/v1/health` and advertises over
Bonjour, and the phone lists it. Confirmed on Davide's iPhone against his MacBook on 2026-08-19 —
across a wired Mac and a wireless phone, so his network bridges mDNS between the two segments.

Selecting a Mac still does nothing: the phone has no API client beyond health and no pairing. What
changed is the other end — the Mac now serves the whole read API, and a terminal can drive it.

## Milestones

The spec's milestones, each ending in something runnable and a green suite, with a review gate.

| | Milestone | State |
|---|---|---|
| M0 | Scaffold — layout, manifest, CI, ruleset, harness, fixtures | **done** |
| — | Delivery — Xcode Cloud archives `main` to TestFlight (iOS) | **done** |
| M1 | Diff parser, display columns, word diff; path grouping into a tree | **done** |
| M2 | Git layer, worktree services, JSON store, session index, HTTP API, CLI | **done** |
| M3 | Menu bar app — settings, Bonjour, pairing, login item, connection log | |
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
- Six gating CI jobs on a pinned Xcode 26.6 / macOS 26 runner. 207 package tests in 21 suites, plus
  the snapshot suite on a simulator.
- `/v1/health`, served over plain HTTP under `--insecure-http` and advertised as `_granita._tcp`
  otherwise, with the advertised port confirmed to be the one actually serving.
- An Xcode Cloud workflow archiving `main` to TestFlight for internal testers.

## Verified against the real environment

Findings from the spec's verify-first pass are in [`verification.md`](verification.md). The short
version: every git trap in the spec reproduces on git 2.52.0 and 2.55.0, all three dependencies are
current and resolve, and the module graph compiles.

Still unverified, because each needs code that does not exist yet:

- Highlightr's throughput on a 200-line Swift block, measured on device (M5).
- The `MenuBarExtra` plus `Settings` pattern under `LSUIElement` on macOS 26, and login-item
  registration (M3).
- Character-wrapping height arithmetic against measured heights (M5).
- Self-signed identity plus pinned trust evaluation against App Transport Security on device (M4).

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

**M3, the menu bar app.** M2 is done and the backend is real: a terminal can enable a repository
and read every endpoint. What it cannot do is any of the things that need a window or a Keychain.

M3 is `ServerMacUi` and `ServerMacPresentation` plus the shell: the menu bar item and its state,
Settings with explicit project enabling, the login item, the connection log, wake-from-sleep rebind,
and the two things M2 deliberately left at the door — **the TLS identity in the Keychain** and
**pairing with a QR code**, which SPEC §12 puts in M3 and which are why `--insecure-http` exists.
Acceptance is pairing from a real device on the LAN and hitting the API.

Two smaller things M2 left for whoever is next in these modules:

- **Resolving the git binary** (`/usr/bin/git`, then `xcrun -f git`, then `PATH`). The executable is
  a constructor parameter and the CLI probes three fixed paths; the `xcrun` step is itself a
  subprocess and wants its own seam.
- **Pinning the JSON encoder.** Timestamps are ISO 8601 because that is the framework's default, and
  a test asserts the raw shape so a change is red rather than silent. Setting it deliberately is a
  small job for the next change in the API module.

## Waiting on Davide

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
