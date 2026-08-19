# Status

Where the project is. Update this when a slice lands.

**Version 0.0.1.** Scaffold complete, CI green, `main` protected. No product behaviour yet.

## Milestones

The spec's milestones, each ending in something runnable and a green suite, with a review gate.

| | Milestone | State |
|---|---|---|
| M0 | Scaffold — layout, manifest, CI, ruleset, harness, fixtures | **done** |
| M1 | `CoreDiffDomain` parser, display columns, word diff; `CoreTreeDomain` grouping | next |
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
- Four gating CI jobs on a pinned Xcode 26.6 / macOS 26 runner.

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

- Apple Developer Program membership, and a Developer ID Application certificate.
- Bundle identifiers registered, an App Store Connect record for the phone app, an internal
  TestFlight tester group, and accepted agreements.
- Apple's GitHub app installed on this repository.
- The two Xcode Cloud workflows, created in Xcode.app.
- The first project folder to add.
