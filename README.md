# Granita

**Read the code your agent wrote, from your phone.**

Claude Code does most of its work in git worktrees, so at any moment there are several worktrees
across several projects, each holding uncommitted changes waiting to be looked at — and their
directory names are auto-generated, so they are impossible to tell apart. Reviewing that from a
phone means remote-controlling the Mac over VNC, which is slow and terrible on a small screen.

Granita is two halves of one product:

- a **macOS menu bar app** that holds a list of git projects you have explicitly added, enumerates
  their worktrees, computes diffs, and serves them over your local network;
- a **native iOS and iPadOS client** that renders those diffs properly on a phone — syntax
  highlighting, a directory-grouped file tree, word-level intra-line diff, mark-as-viewed, and the
  reading ergonomics of a real review tool.

v1 is read-only apart from worktree aliases and pins. You review on the phone, then talk to Claude
in the mobile app as usual. Inline comments and pushing feedback back into the agent are v2.

Nothing is exposed to the phone until you enable it explicitly, and the connection is TLS with a
pinned certificate — the payload is your private source code.

The full specification, including the empirically-verified traps the implementation must not
simplify away, is in [`SPEC.md`](SPEC.md).

## Stack

| | |
|---|---|
| Language | Swift 6, strict concurrency `complete`, every target |
| Minimum OS | iOS 26.0, iPadOS 26.0, macOS 26.0 |
| UI | SwiftUI — `MenuBarExtra` on the Mac, `NavigationSplitView` on the phone and iPad |
| Server | Hummingbird 2 on a `NIOTSEventLoopGroup`, in-process in the menu bar app and also a CLI |
| Git access | The `git` binary via swift-subprocess, behind a `GitClient` protocol |
| Persistence | One JSON document, actor-guarded, atomic replace. No SQLite, no SwiftData |
| Highlighting | Highlightr |
| Tests | Swift Testing, TDD, golden fixtures generated from the real `git` binary |
| Xcode project | Generated from `project.yml` by XcodeGen. Never hand-edited |

Exactly three external dependencies — Hummingbird, Highlightr, swift-subprocess — each pinned to
exactly one target.

## Layout

One local package holds everything testable; the two Xcode targets are thin `@main` shells over
it, so `swift test` runs the whole logic suite with no simulator and no Xcode.

```
Packages/Granita/<Unit>/<Feature>/<Layer>
```

A target's module name is its path with the slashes removed — `Client/Viewer/Data` is
`import ClientViewerData`. The layers are `Domain`, `Data`, `Presentation` and `Ui`, and the rules
between them are enforced by the target dependency graph in `Package.swift`, not by review: a
dependency a target does not declare is a dependency that does not compile.

## Build, test, run

```bash
make test        # package test suite — no simulator, no Xcode
make build       # compile-check the package and both apps
make run         # run the backend in a terminal
make project     # regenerate Granita.xcodeproj from project.yml
make fixtures    # rebuild the git fixture repos and the golden diff fixtures
```

`make help` lists the rest.

`main` is PR-gated: land every change through a pull request and wait for the checks.

## Changelog

### 0.0.1 — 2026-08-19
- **The project exists and builds end to end.** Both apps compile and launch empty, the backend
  runs from a terminal, and the test suite is green. The module graph for every feature is in
  place, so the layer rules are enforced by the compiler from the first commit rather than agreed
  in a document. Golden diff fixtures are generated from the real `git` binary and committed, so
  the parser suite has something to assert against before a line of it is written.
