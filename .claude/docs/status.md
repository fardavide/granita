# Status

Where the project is. Update this when a slice lands.

**Version 0.0.2.** Scaffold complete, CI green, `main` protected, **shipping to TestFlight**.

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
| M1 | `CoreDiffDomain` parser, display columns, word diff; `CoreTreeDomain` grouping | after the snapshot harness |
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
- Four gating CI jobs on a pinned Xcode 26.6 / macOS 26 runner. 9 tests, 3 suites.
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

In order, and the first one is already agreed rather than open:

1. **`swift-snapshot-testing`.** Davide approved it as a **fourth, test-only** dependency — linked to
   an app-hosted test target, never to a shipped product, so the apps stay on three. It was deferred
   from the discovery slice only so that could reach his phone sooner. The first subject is the
   discovery view, which is stateless and therefore renderable in all five of its states without a
   Mac or a granted permission: searching, nothing found, a list, permission refused, failed — light
   and dark, iPhone and iPad.

   **The CI job and the ruleset must move together.** Adding the job without adding its name to
   `.github/rulesets/protect-main.json` leaves a check that can fail without blocking anything;
   adding the name without the job leaves every pull request pending forever, with no bypass to
   escape through. Same pull request, both.

2. **M1, the diff parser.** The 25 golden fixtures are committed and cover every case in SPEC §6, so
   it can be written test-first against real `git` output from the first failing test.

## Waiting on Davide

- **The refused-permission path, seen on device.** Granting works and is confirmed; denying is not.
  It is covered by a test through a fake, but the real thing cannot be exercised in the simulator —
  which does not implement local network privacy at all — so whether the screen reads right when iOS
  actually withholds the permission is still unknown. Turn it off under Settings › Granita › Local
  Network to check.
- A **second Xcode Cloud workflow for the Mac app**, archiving with Developer ID and notarising.
  Not started; the Mac app runs locally in the meantime, and only distribution needs it.
