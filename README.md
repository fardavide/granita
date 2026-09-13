<h1 align="center">Granita</h1>

<p align="center"><strong>Read the code your agent wrote, from your phone.</strong></p>

<p align="center">
  A macOS menu bar app serves the uncommitted diffs of the git worktrees you have switched on.
  A native iPhone and iPad app renders them with the ergonomics of a real review tool.
</p>

<p align="center">
  <img src="Apps/GranitaMobileSnapshotTests/__Snapshots__/ReadmeScreenshotTests/screenshot-of.diff-iPhone-light.png" width="270" alt="A diff on iPhone, in light mode">
  <img src="Apps/GranitaMobileSnapshotTests/__Snapshots__/ReadmeScreenshotTests/screenshot-of.diff-iPhone-dark.png" width="270" alt="The same diff in dark mode">
</p>

---

# Part one — the product

## The problem

Claude Code does most of its work in git worktrees. At any moment there are several of them across
several projects, each holding uncommitted changes waiting to be looked at, and their directory names
are auto-generated — so they are impossible to tell apart. Reviewing that from a phone means
remote-controlling the Mac over VNC, which is slow and terrible on a small screen.

Granita is two halves of one product:

- a **macOS menu bar app** that holds the git projects you have explicitly added, enumerates their
  worktrees, computes diffs, and serves them over your local network;
- a **native iOS and iPadOS client** that renders those diffs properly — syntax highlighting, a
  directory-grouped file tree, word-level intra-line diff, mark-as-viewed, and comments you can hand
  straight back to the agent.

## How it works

1. **Switch on what may be read.** On the Mac, add your repositories and enable the ones a phone may
   see. Nothing on the machine is visible until you do this, and adding and enabling are two separate
   acts on purpose.
2. **Pair once.** Point the phone's camera at the QR code in the Devices tab, or type the six words
   under it. The pairing pins your Mac's certificate, so the phone will only ever talk to that
   machine.
3. **Read.** Open the Mac, pick a worktree, and scroll the change set. Comments go in as you read;
   *Copy review* puts the whole thing on the clipboard for the agent.

## The screens

### Finding your Mac, and picking up a change set

The first screen lists the Macs serving on your network. Opening one lists its worktrees — grouped by
project, most recently changed first, with what moved and how long ago. Worktrees with nothing
uncommitted are hidden, and the list says how many it hid. Renaming one names it on your phone and
never touches git; pinning it floats it to the top.

<table>
  <tr>
    <td width="50%"><img src="Apps/GranitaMobileSnapshotTests/__Snapshots__/ReadmeScreenshotTests/screenshot-of.macs-iPhone-light.png" alt="The list of Macs serving on the local network"></td>
    <td width="50%"><img src="Apps/GranitaMobileSnapshotTests/__Snapshots__/ReadmeScreenshotTests/screenshot-of.worktrees-iPhone-light.png" alt="A Mac's worktrees, grouped by project"></td>
  </tr>
  <tr>
    <td align="center"><em>Macs on the network</em></td>
    <td align="center"><em>One Mac's worktrees</em></td>
  </tr>
</table>

### The diff

Every changed file in one continuous scroll. The code is syntax highlighted the way Xcode colours it,
long lines scroll sideways rather than reflowing, and the words that actually changed within a line
carry a stronger highlight behind them. A torn band says how many lines the diff skipped and which
declaration you are inside; tap it to open twenty more. Marking a file read shuts it, so a long review
keeps its place.

<table>
  <tr>
    <td width="50%"><img src="Apps/GranitaMobileSnapshotTests/__Snapshots__/ReadmeScreenshotTests/screenshot-of.diff-iPhone-light.png" alt="A diff on iPhone in light mode"></td>
    <td width="50%"><img src="Apps/GranitaMobileSnapshotTests/__Snapshots__/ReadmeScreenshotTests/screenshot-of.diff-iPhone-dark.png" alt="The same diff on iPhone in dark mode"></td>
  </tr>
  <tr>
    <td align="center"><em>Light</em></td>
    <td align="center"><em>Dark</em></td>
  </tr>
</table>

Both shots are the same state: a conflicted file with its markers left uncoloured, a word-level change
on line 141, a file still arriving from the Mac, and two comments already written — the indigo bars in
the gutter, the count in the file's header, and the *Review* capsule that appears once anything is
written.

### Comments, and getting them back to the agent

Tap the line numbers beside a line to comment on it; press and hold, then tap another line, to comment
on a run. A comment is a thin indigo bar beside the lines it covers, and nothing moves when you write
one. The review itself is one screen: an optional note for the agent, then every comment in the order
the diff draws them. A comment whose lines the agent has since changed says *stale* rather than
disappearing, and is still included when you copy.

<p align="center">
  <img src="Apps/GranitaMobileSnapshotTests/__Snapshots__/ReadmeScreenshotTests/screenshot-of.review-iPhone-light.png" width="300" alt="The review screen, with a note for the agent and four comments">
</p>

The comments live on the phone that wrote them and nowhere else. You copy the review and paste it to
the agent yourself — pushing it back into the session automatically is v2.

### iPad

On an iPad the file tree is a column of its own, permanently beside the code, which is where this
reads like a review tool rather than a phone app. The worktree list is the split view's sidebar; open a
worktree and it gives its room to the code. Open the review and it takes the tree's column, so the diff
keeps its width instead of being squeezed into a third of the window.

<p align="center">
  <img src="Apps/GranitaMobileSnapshotTests/__Snapshots__/ReadmeScreenshotTests/screenshot-of.worktrees-iPad-light.png" width="800" alt="iPad split view: worktrees in the sidebar, an empty detail column">
</p>

<p align="center">
  <img src="Apps/GranitaMobileSnapshotTests/__Snapshots__/ReadmeScreenshotTests/screenshot-of.diff-iPad-light.png" width="800" alt="iPad: the file tree column beside the continuous diff">
</p>

<p align="center">
  <img src="Apps/GranitaMobileSnapshotTests/__Snapshots__/ReadmeScreenshotTests/screenshot-of.review-column-iPad-light.png" width="800" alt="iPad: the review column in the file tree's place, beside the diff">
</p>

### On the Mac

The Mac app has no Dock icon and no window — it is a menu bar item and a Settings window. **Projects**
is where you decide what a phone may read, and scanning a folder never adds anything on its own: what
it finds opens in a sheet with nothing ticked, and everything it adds arrives switched off.

<p align="center">
  <img src="Apps/GranitaMacSnapshotTests/__Snapshots__/ProjectsSettingsViewSnapshotTests/given-a-Projects-state-when-rendering-then-it-matches-its-baseline-subject-appearance.settled-light.png" width="760" alt="The Mac's Projects settings tab, with per-project switches">
</p>

The other tabs are **General** (the address this Mac serves on, and what to do when it is not
serving), **Devices** (the pairing code, and every phone that has paired, each with a Revoke),
**Connections** (a log of every device that reached this Mac and what happened to it) and
**Advanced** (verbose logging, the git binary in use, and Reset All Data).

## What Granita is not

It is **not a git client and not a history browser**. It shows uncommitted work in a worktree, not
commits, branches or blame. v1 never writes to your source: a worktree's name and its pin live on the
phone and never touch git, and the one thing it does change on the Mac is deleting a worktree —
deliberately behind a long press, with a confirmation that counts what you are about to lose.

## Privacy and security

- **Nothing is exposed until you say so.** A repository has to be added *and* switched on.
- **The wire is TLS with a pinned certificate.** The Mac generates its own identity on first run and
  keeps it in the login Keychain; a phone that paired with one Mac refuses to talk to anything else
  answering on the same address.
- **The API never accepts a filesystem path.** The client only ever sends opaque identifiers the
  server resolves against its own registry of enabled projects. That is the security boundary, not a
  style preference.
- **A pairing code is good for two minutes and one device**, whether it is scanned or typed, and
  guessing is rate limited per device.
- **The logs never contain your source.** Granita records the command and the checkout it ran in,
  never git's output; the method and path of a request, never its query or its body.

## When something will not connect

Tap **Copy Logs** on the error screen and paste the result into your message. The report carries the
app version, timestamps, connection endpoints, route verification, TLS pin outcomes and error codes
from the current app session — no credentials, no pairing codes, no request bodies, no source text.
You do not need to attach the phone to a Mac or make an archive. If you reopened Granita since the
problem, reproduce it first.

## What's new

### 0.12.1 — 2026-09-13
- **A file that has not arrived draws a short placeholder instead of a full-height one.** 0.12.0
  sized it from the line count your Mac reports, which cannot include the expanders a drawn file
  gets — so a long file reserved most of a screen and then landed somewhere else entirely.
- **The diff now moves into place instead of snapping.** The placeholder fades into the code and the
  file grows to its real height on the same curve everything else on this screen opens with.

### 0.12.0 — 2026-09-13
- **A file you are waiting for now says so.** Where a diff that had not arrived drew an empty card
  under its header, it draws the rows the file has not sent yet — one line of type saying
  `reading from your Mac`, and a slow sweep of light across the card.
- **A diff that never arrives no longer looks like one that is still coming.** A file whose batch
  your Mac refused stops sweeping, dims, and says `couldn’t read this file`.
- **And there is something to press about it.** A bar at the bottom of the diff says how many files
  could not be read and why, and offers the one action that can help.

### 0.11.4 — 2026-09-13
- **Opening a Mac explains what Granita is waiting for.** Finding a route, checking the paired
  key and reading worktrees have distinct labels. Long waits show elapsed time and offer Copy Logs.
- **Refresh keeps your worktrees available.** Pull to refresh, retry a stale read inline, and see
  when the list was last read.
- **Revoked pairings offer Pair Again.** The action opens the selected Mac's pairing screen.

**[Every release is in `CHANGELOG.md`.](CHANGELOG.md)**

---

# Part two — the engineering

## Stack

| | |
|---|---|
| Language | Swift 6, strict concurrency `complete`, every target |
| Minimum OS | iOS 26.0, iPadOS 26.0, macOS 26.0 |
| UI | SwiftUI throughout — `MenuBarExtra` under `LSUIElement` on the Mac, `NavigationSplitView` universal on the phone and iPad. `@Observable`, never `ObservableObject` |
| Server | Hummingbird 2 on a `NIOTSEventLoopGroup`, so listening and Bonjour advertising happen in one bind. In-process in the menu bar app, and also a standalone executable |
| Git access | The `git` **binary** via swift-subprocess, behind a protocol — not libgit2, which diverges from git exactly on worktrees and index state |
| Networking | `URLSession` with a custom server-trust evaluation. No Alamofire |
| Persistence | One JSON document, actor-guarded, atomic replace. No SQLite, no SwiftData, no Core Data |
| Highlighting | Highlightr |
| Tests | Swift Testing, TDD, golden fixtures generated from the real `git` binary, snapshot baselines per screen |
| Xcode project | Generated from `project.yml` by XcodeGen, committed, never hand-edited |

**Exactly three external dependencies** — Hummingbird, Highlightr, swift-subprocess — each pinned to
exactly one target. There is no DI framework, no service locator and no mocking framework.

The Mac app is **deliberately unsandboxed**: a sandboxed process cannot exec `git` against arbitrary
folders. That is why every git call goes through a protocol — a libgit2 backend could replace the
process-based one without touching a call site, which keeps a sandboxed build possible later.

## The two halves and the wire between them

A Mac holds the source and the `git` binary. A phone holds the reader. Between them is a JSON API over
pinned TLS. Bonjour discovers the Mac on the LAN; after pairing, a stable Tailscale endpoint can
reconnect the same pinned session across networks, and on Wi-Fi the first route to complete pinned
HTTPS verification wins. Discovery alone cannot win a race — a route has to verify.

The Mac app embeds the backend in-process, and the same backend is also an executable, so the whole
server side builds, runs and is tested from a terminal with no Xcode in the loop. The menu bar app is a
delivery mechanism for it, not its host.

## One package, four layers, boundaries the compiler enforces

Everything testable lives in one local Swift package. The two Xcode targets are thin `@main` shells
linking one product each, so nothing worth testing is trapped in an app bundle and the whole logic
suite runs on the host with no simulator.

A feature is a **directory** holding one module per layer:

```
Packages/Granita/<Unit>/<Feature>/<Layer>
```

A module's name is its path with the slashes removed — `Client/Viewer/Data` is
`import ClientViewerData` — so the tree on disk and the import list say the same thing. `Unit` is
`Core` (both platforms), `Client` (iOS and iPadOS) or `Server` (macOS-only).

| Layer | May depend on | Never |
|---|---|---|
| `Domain` | other `Domain` targets, Foundation | frameworks, I/O |
| `Data` | `Domain`, plus at most **one** external infra dependency | another `Data`'s internals |
| `Ui` | `Domain` for what it renders, SwiftUI | any `Presentation`, any `Data` |
| `Presentation` | its feature's `Ui`, `Domain` | any `Data` target |
| `Main` | anything — it is a composition root | being depended on by anything |

There is no single chain: each layer depends on `Domain` and on nothing else in the list. `Data` and
the two view layers never meet — they are siblings over `Domain`, not a pipeline. The rules are
declared once in `Package.swift` and enforced by the compiler: a dependency a target does not declare
is a dependency that does not compile.

**`Presentation` depends on `Ui`**, which inverts what most SwiftUI projects do and is deliberate. A
`Ui` module is a vocabulary of stateless views — each takes what it renders and reports what happened,
owning no view model. `Presentation` owns the view models and composes screens out of those views. A
view that imported its view model could only serve the one screen that view model belonged to; a view
that takes values and closures serves any screen that has them.

Anything touching the outside world sits behind a protocol owned by a `Domain` module, with one
implementation in `Data` and a **hand-written fake** in tests. Types are built with constructor
injection, so a test constructs the subject directly with the doubles it wants.

Only three modules import a `Data` target, because wiring implementations into protocols is their
whole job: they are the `Main` layer — the phone's composition root, the menu bar app's, and the
`granita-server` executable's. A `Main` module holds wiring and nothing else; it is exempt from both
coverage rows, so logic left in one is untested code that no longer looks untested.

Identifiers are **opaque typed wrappers**, never unwrapped for convenience, and the API never accepts a
filesystem path as an input.

## Repository layout

```
Apps/                  thin @main shells, plus the snapshot and UI test targets
Packages/Granita/      every module: Core, Client, Server × Feature × Layer
Scripts/               fixture generation, coverage, icons
Art/                   app icon sources
.ai/                   AGENTS.md, docs/ (architecture, decisions, design, status), skills/
project.yml            the XcodeGen source of Granita.xcodeproj
SPEC.md                the specification
```

## Build and test

```bash
make test        # package test suite — no simulator, no Xcode
make build       # compile-check the package and both apps, unsigned
make coverage    # the coverage gate's own verdict, locally
make snapshots   # render the screens on a simulator against the committed baselines
make run         # run the backend in a terminal
make project     # regenerate Granita.xcodeproj after editing project.yml
make fixtures    # rebuild the git fixture repos and the golden diff fixtures
```

`make help` lists the rest. CI runs four required checks on every pull request: **Unit tests**,
**Build app** (macOS and iOS), **Generated files** — which regenerates the Xcode project and the
fixtures and fails if the committed copies are stale — and **Coverage**, which is a ratchet against
`main` with no slack.

Testing is **Swift Testing, not XCTest**, and TDD: a failing test first, then the minimum to pass.
Test names read `` `given X when Y then Z` `` as backtick raw identifiers. The diff parser asserts
against golden fixtures generated from the real `git` binary, so it has something true to compare with
rather than a hand-written approximation of git's output.

**Every screenshot above is a snapshot baseline**, rendered by
[`ReadmeScreenshotTests`](Apps/GranitaMobileSnapshotTests/ReadmeScreenshotTests.swift) on a simulator
and by the Mac's own suite on the CI runner. There is no folder of exported images, because an
exported image is correct on the day it is exported and silently wrong afterwards: a screen that moves
turns these red on the pull request that moved it, alongside every other baseline it moved.

## How a change lands

`main` is PR-gated by a ruleset with **no bypass for anyone**: squash only, linear history, all four
checks green. **Merging to `main` publishes** — every squash merge archives the phone app on Xcode
Cloud and lands it on TestFlight — so the version bump in `project.yml` and its `CHANGELOG.md` entry
have to be right *before* the pull request goes green. A build cannot be un-published. `[ci skip]` in
a commit title is the escape hatch for a docs-only merge.

The Mac app is **built by hand** (`make run-mac`), not by Xcode Cloud, so a change to the server half
reaches a phone only once somebody rebuilds and restarts the menu bar app.

## Where the reasoning lives

- **[`SPEC.md`](SPEC.md)** — the specification. Its paragraphs marked TRAP describe defects found by
  running things rather than by reading documentation, and are not to be simplified away.
- **[`.ai/docs/architecture.md`](.ai/docs/architecture.md)** — the module tree and why the shape holds
  itself together.
- **[`.ai/docs/decisions.md`](.ai/docs/decisions.md)** — every place this repository knowingly departs
  from the spec, and why.
- **[`.ai/docs/design.md`](.ai/docs/design.md)** and
  **[`.ai/docs/design-mac.md`](.ai/docs/design-mac.md)** — both halves are designed down to the
  screen; a design question is a lookup, not an open question.
- **[`.ai/docs/status.md`](.ai/docs/status.md)** — where the project is right now.
- **[`.ai/skills/`](.ai/skills)** — the actionable rules an agent working here has to follow.
