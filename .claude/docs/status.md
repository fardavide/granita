# Status

Where the project is. Update this when a slice lands.

**Version 0.0.4.** Scaffold complete, CI green, `main` protected, **shipping to TestFlight**.

The two halves find each other **on real hardware**: the Mac serves `/v1/health` and advertises over
Bonjour, and the phone lists it. Confirmed on Davide's iPhone against his MacBook on 2026-08-19 —
across a wired Mac and a wireless phone, so his network bridges mDNS between the two segments.

Selecting a Mac does nothing yet: there is no pairing, no API client beyond health, and nothing to
read.

## Milestones

The spec's milestones, each ending in something runnable and a green suite, with a review gate.

| | Milestone | State |
|---|---|---|
| M0 | Scaffold — layout, manifest, CI, ruleset, harness, fixtures | **done** |
| — | Delivery — Xcode Cloud archives `main` to TestFlight (iOS) | **done** |
| M1 | Diff parser, display columns, word diff; path grouping into a tree | **done** |
| M2 | Git layer, worktree services, JSON store, session index, HTTP API, CLI | |
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
  deterministic order that does not inherit the one the diff arrived in. Waiting on the git layer too.
- Six gating CI jobs on a pinned Xcode 26.6 / macOS 26 runner. 96 package tests in 10 suites, plus
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
- One real Claude Code session transcript's record shape (M2).
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

**M2, the git layer.** M1 is done, so the whole of `Core` is a library nothing calls yet. M2 is the
largest remaining slice and the one that finally connects it to something. Its traps are catalogued
in SPEC §5 and verified in `verification.md`, and it inherits two requirements from M1:

- the diff-family invocation must pin the `a/` and `b/` path prefixes, because `diff.noprefix` in
  Davide's own configuration would otherwise remove the first two characters of every path with no
  error anywhere;
- SPEC §4's `FileChange` lands with it rather than with the tree, and it is the first type that has
  to say how an opaque identifier encodes on the wire — the spec carries no JSON example, so that is
  a decision M2 makes rather than inherits.

## Waiting on Davide

- **The refused-permission path, seen on device.** Granting works and is confirmed, and 0.0.4 fixed
  the false refusal Davide hit by backgrounding the app and coming back. What is still unconfirmed on
  hardware is the true one: whether a browser that iOS really is withholding permission from dies
  three times over and reaches the Settings screen within a couple of seconds, rather than sitting on
  "Looking for your Mac". The simulator does not implement local network privacy at all, so only a
  device can say. Turn it off under Settings › Granita › Local Network to check, then turn it back on
  without relaunching — the screen should find the Mac again on its own within five seconds.
- A **second Xcode Cloud workflow for the Mac app**, archiving with Developer ID and notarising.
  Not started; the Mac app runs locally in the meantime, and only distribution needs it.
