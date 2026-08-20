# Granita: build prompt for Claude Code

> **Read section 0 first.** It says who made each decision. That distinction is binding: choices
> marked LOCKED are Davide's and are not open for substitution, choices marked PROPOSED are the
> author's suggestions and you should say so if you think one is wrong.
>
> Paragraphs marked **TRAP** describe defects found by empirical testing against real `git`, real
> package sources and current Apple documentation, not by reading docs. Do not simplify them away.
> Items marked **VERIFY** must be checked against the real environment before code is written.
>
> Where the repository has since diverged from this document, the divergence is recorded in
> `.claude/docs/decisions.md` with its reason. This file is the specification; that file is the
> history of departures from it.

---

## 0. Decision provenance

This section exists because an earlier draft of this spec presented the author's own guesses as
settled decisions. Every technical choice below now carries its source.

### LOCKED, decided by Davide

Not open for substitution. If you think one is wrong, stop and say so rather than working around it.

| Decision | Value |
| --- | --- |
| Name | **Granita** |
| Client | Native iOS and iPadOS app, SwiftUI, universal, iPad split view in v1 |
| Server language | Swift |
| Minimum OS | iOS 26.0, iPadOS 26.0, macOS 26.0 |
| Diff scope | Uncommitted changes only, staged and unstaged and untracked. No committed history |
| File list | Directory grouped like Android Studio, including single-child chain compaction |
| Worktree naming | Display alias, never a git rename. Auto-suggested from the Claude Code session |
| Worktree actions | Set alias, pin. Nothing else mutates anything |
| Project discovery | Manual opt-in only. Nothing is exposed to the phone until it is enabled explicitly |
| Worktree list | Toggle between grouped by project and flat |
| v1 scope | Viewer only. Comments are v2 |
| v1 viewer features | Syntax highlighting, word level intra-line diff, mark file as viewed, collapsed context |
| Diff navigation | One continuous scroll across all files, plus a file selector, plus a wrap toggle |
| Network | LAN only in v1 |
| Live updates | Yes in v1. Pushing feedback into Claude is v2 |
| Distribution | Paid Apple Developer Program, TestFlight |
| Persistence | No SQL. The data is tiny and does not justify a database |
| Modules | `<Unit>/<Feature>/<Layer>` directory tree with flat concatenated module names (`import ClientViewerData`). Layers: `Domain`, `Data`, `Ui` (stateless SwiftUI views only), `Presentation` (view models, mappers, screen composition). **`Presentation` depends on `Ui`**, not the reverse. Following Oltre |
| Execution | Milestones with approval gates. Stop after each one |

### DELEGATED, decided by the author at Davide's request

Treat them as settled, but the reasoning is written out so you can challenge it if you find a real
problem.

| Decision | Value | Why |
| --- | --- | --- |
| Transport | TLS, self-signed identity, SPKI pinning | Payload is private source code, the LAN holds many third-party IoT devices, and pairing is the thing you do not want to redo when v2 adds remote access |
| Server process | In-process inside the menu bar app, backend also builds as a CLI | Simplest thing that works. A launchd helper is better in steady state but riskier to set up, and the dominant failure is the Mac sleeping, which no process model fixes |
| App architecture | MVVM plus a service layer, constructor injection, protocol at every I/O edge | Meets SOLID, strong typing, testability and maintainability without use-case ceremony on a read-only viewer |
| HTTP framework | Hummingbird 2 | The modern idiomatic one: async/await native, structured concurrency throughout, no EventLoopFuture legacy, small |
| Git access | Shell out to the `git` binary, behind a `GitClient` protocol | git is the source of truth for worktrees and index state, and libgit2 diverges exactly there. The protocol keeps a libgit2 backend possible later |
| Xcode project | XcodeGen from `project.yml` | An agent hand-editing a `.pbxproj` corrupts projects. This removes the failure mode |
| Store format | JSON, actor-guarded, atomic replace | Hundreds of rows, one writer, no queries. A database would be ceremony |

### PROPOSED by the author, override freely

- **Highlightr** rather than HighlightSwift, for a specific technical reason in §2.
- **Opaque SHA-256 IDs** in the API instead of filesystem paths, to close a traversal hole.
- **Bonjour discovery plus QR pairing**, so no IP address is ever typed on a phone.
- **`git worktree list --porcelain -z`** as the source of truth rather than the `.claude/worktrees/`
  directory layout, which is an undocumented implementation detail.
- **Not sandboxed**, which is forced by exec-ing `git` against arbitrary folders, not a free choice.
- **Swift Testing and TDD.**
- **SSE plus FSEvents** for live updates rather than polling.
- **Character-wrapping arithmetic** for height prediction, §10.
- **Demo mode**, a bundled fixture dataset. Cut it if it is not worth the code.
- **swift-subprocess** as the third dependency, justified in §2.
- **OSLog** rather than swift-log.

---

## 1. The problem

Davide does roughly 90% of his development work from an iPhone, driving Claude Code sessions on a
MacBook Pro through the Claude mobile app, with `claude rc` running in the desktop CLI. The one
thing he cannot do from the phone is **read the code the agent wrote**. Today that means remote
controlling the Mac with Screens 5 over VNC, which is slow, fiddly and terrible on a phone screen.

Claude Code runs most of its work in git worktrees, so at any moment there are several worktrees
across several projects, each holding uncommitted changes waiting to be looked at. Their directory
names are auto generated, random adjective-noun-noun, so they cannot be told apart.

**Granita** is a two part product:

- a **macOS menu bar app** that holds a list of git projects explicitly added, enumerates their
  worktrees, computes diffs, and serves them over the local network;
- a **native iOS and iPadOS client** that renders those diffs properly on a phone, with syntax
  highlighting, a directory grouped file tree, and the reading ergonomics of a real review tool.

v1 is read only apart from aliases and pins. Review on the phone, then talk to Claude in the mobile
app as before. v2 adds inline comments and pushes collected feedback back to the agent. The v1
architecture must not make v2 expensive, but v1 must not build v2.

**Naming in code.** Keep the product name, bundle identifier prefix, Bonjour service type, URL
scheme and Application Support directory in a single `Branding.swift` plus `project.yml`, so a
rename is a two file change.

---

## 2. Technology

| Area | Choice | Source |
| --- | --- | --- |
| Language | Swift 6, strict concurrency `complete`, every target | LOCKED (Swift), PROPOSED (strict concurrency) |
| Minimum OS | iOS 26.0, iPadOS 26.0, macOS 26.0 | LOCKED |
| Package | One local package `Granita`; targets follow the `<Unit>/<Feature>/<Layer>` tree in §3, module name = path segments concatenated | LOCKED |
| Apps | Two Xcode targets, `GranitaMac` and `GranitaMobile`, thin `@main` shells over the package | LOCKED |
| Persistence | JSON file, actor-guarded, atomic replace. No SQLite, no SwiftData, no Core Data | LOCKED |
| HTTP server | Hummingbird 2 on a `NIOTSEventLoopGroup`, see §8 for why NIOTS specifically | DELEGATED |
| Git access | The `git` binary via `swift-subprocess`, behind a `GitClient` protocol | DELEGATED |
| macOS UI | SwiftUI, `MenuBarExtra` plus `Settings` scene, `LSUIElement` true | PROPOSED |
| iOS UI | SwiftUI, `@Observable`, `NavigationSplitView`, universal | LOCKED (universal, split view) |
| Networking, client | `URLSession`, async/await, custom server-trust evaluation. No Alamofire | PROPOSED |
| Serialisation | `Codable`, camelCase keys on both sides | PROPOSED |
| Syntax highlighting | **Highlightr**, not HighlightSwift, see TRAP below | PROPOSED |
| Hashing | CryptoKit SHA-256 | PROPOSED |
| Logging | OSLog | PROPOSED |
| Testing | Swift Testing (`import Testing`), not XCTest, TDD throughout | PROPOSED |
| Xcode project | Generated by XcodeGen from `project.yml`. Never hand edit a `.pbxproj` | DELEGATED |

**Dependencies: exactly three.** Hummingbird 2, Highlightr, swift-subprocess. Nothing else without
asking first. Each one pins to exactly one target: swift-subprocess in `ServerGitData`, Hummingbird
in `ServerApiPresentation`, Highlightr in `ClientViewerUi` (highlighting produces attributed strings
for rendering, which is Ui work). No other target may declare an external product.

**Why swift-subprocess.** `Foundation.Process` deadlocks when a child writes more into a pipe than
the buffer holds unless both streams are drained concurrently, and `git diff` output does exactly
that. It also gives the child the app's own process group, which makes timeout handling dangerous,
see §5.1. swift-subprocess is `Sendable`, streams stdout and stderr as `AsyncSequence`, and removes
the whole class of bug.

**TRAP, syntax highlighting.** Do not use `HighlightSwift`. Its `request(...)` renders highlight.js
output to HTML and then builds the attributed string with the AppKit/UIKit HTML importer, which is
main-thread-only, so "highlight off the main actor" is unimplementable with it and fails as silent
hangs rather than compile errors. It also calls `trimmingCharacters(in: .whitespacesAndNewlines)` on
the input, destroying the leading indentation of the first line and all trailing blank lines, which
is fatal for a join-then-split-per-line strategy. It also indexes `length - 1` and crashes on empty
input. Use **Highlightr** instead: same highlight.js engine in JavaScriptCore, but it builds the
attributed string itself with no HTML importer and no trimming. `JSContext` is not shareable across
threads, so hold exactly one `Highlightr` instance per background actor for the app lifetime.
Construction loads the JS bundle and costs about 100 ms.

**Why XcodeGen.** All targets are described in YAML. `make project` regenerates the project.
XcodeGen generates a **project**, not a workspace: one `.xcodeproj` with a `GranitaMac` target
(`platform: macOS`) and a `GranitaMobile` target (`supportedDestinations: [iOS, iPadOS]`), both
consuming the local package via `packages: { Granita: { path: Packages/Granita } }`.

**TRAP, dependency pinning.** Gitignoring the `.xcodeproj` also gitignores the `Package.resolved`
inside it, so CI would resolve every remote dependency to whatever is newest. Declare all three
remote dependencies in the committed local `Package.swift` and let `project.yml` reference only the
local package. Commit `Packages/Granita/Package.resolved`.

**Why the backend also builds as a CLI executable.** `granita-server` is an executable target in the
same package, so the whole backend builds, runs and tests with `swift build` and `swift test` and no
Xcode in the loop. At runtime the menu bar app embeds the same library in-process; the CLI is for
development, tests and recovery.

### Sandboxing and distribution

The Mac app is **not sandboxed**, because a sandboxed process cannot usefully exec `git` against
arbitrary user folders. This does not block a public release: Tower, Fork and GitUp all ship
publicly with Developer ID signing and notarisation, outside the Mac App Store. To keep the store
option alive, all git access goes through a `GitClient` protocol with one `ProcessGitClient`
implementation in v1, so a libgit2 backend can drop in later without touching a call site.

**TRAP, bookmarks.** Do **not** build security-scoped bookmark machinery. `.withSecurityScope` is an
App Sandbox facility requiring `com.apple.security.files.user-selected.*`; unsandboxed you get a
bookmark with no security scope and `startAccessingSecurityScopedResource()` returns `false`. Store a
plain bookmark **and** the path, resolve by path, and treat the bookmark as best effort for a future
sandboxed build.

**TRAP, code signing during development.** macOS 15+ has local network privacy, and it tracks program
identity by code signature. Xcode's default "Sign to Run Locally" (ad-hoc) makes the system lose the
app's identity across rebuilds, which shows up as Bonjour registration mysteriously failing or
re-prompting. Sign `GranitaMac` with a real Apple-issued Developer ID identity even in development.

---

## 3. Repository layout

```
granita/
├── Makefile                          # project, build, test, run, fixtures, icons
├── project.yml                       # XcodeGen: GranitaMac + GranitaMobile, thin shells
├── .github/workflows/ci.yml          # macOS runner, pinned Xcode version
├── Packages/
│   └── Granita/
│       ├── Package.swift             # every target path-based, no Sources/ wrapper
│       ├── Core/                     # pure logic, compiles for iOS AND macOS
│       │   ├── Branding/Domain/      # CoreBrandingDomain: the one place the product is named
│       │   ├── Diff/
│       │   │   ├── Domain/           # CoreDiffDomain: models, parser, word diff, displayColumns
│       │   │   └── DomainTests/
│       │   │       └── Fixtures/     # golden unified diff files
│       │   └── Tree/
│       │       ├── Domain/           # CoreTreeDomain: directory grouping, chain compaction
│       │       └── DomainTests/
│       ├── Client/                   # iOS and iPadOS
│       │   ├── Connection/
│       │   │   ├── Domain/           # ClientConnectionDomain: repo protocols, pairing model
│       │   │   ├── Data/             # ClientConnectionData: URLSession, SPKI pinning, Bonjour, SSE
│       │   │   ├── Ui/               # ClientConnectionUi: pairing and not-paired views
│       │   │   └── DataTests/
│       │   ├── Worktrees/
│       │   │   ├── Domain/           # ClientWorktreesDomain: grouping, sorting, pin and alias logic
│       │   │   ├── Data/             # ClientWorktreesData: list fetch + PATCH over the connection
│       │   │   ├── Ui/               # ClientWorktreesUi: sidebar rows, rename sheet. Stateless views
│       │   │   ├── Presentation/     # ClientWorktreesPresentation: view models, row mappers
│       │   │   ├── DomainTests/
│       │   │   └── PresentationTests/
│       │   ├── Viewer/
│       │   │   ├── Domain/           # ClientViewerDomain: expansion, viewed, wrap and prefetch policy
│       │   │   ├── Data/             # ClientViewerData: batched /diffs and /lines fetching
│       │   │   ├── Ui/               # ClientViewerUi: scroll, gutter, focus mode, highlight (Highlightr)
│       │   │   ├── Presentation/     # ClientViewerPresentation: view models, line and hunk mappers
│       │   │   ├── DomainTests/
│       │   │   └── PresentationTests/
│       │   └── App/
│       │       └── Presentation/     # ClientAppPresentation: root scene, composition root
│       └── Server/                   # macOS only, may use macOS-only APIs freely
│           ├── Git/
│           │   ├── Domain/           # ServerGitDomain: GitClient protocol, typed errors
│           │   ├── Data/             # ServerGitData: ProcessGitClient (swift-subprocess)
│           │   └── DataTests/
│           ├── Worktrees/
│           │   ├── Domain/           # ServerWorktreesDomain: enumeration, status, diff, hashing
│           │   └── DomainTests/
│           ├── Sessions/
│           │   ├── Data/             # ServerSessionsData: Claude JSONL index → suggested aliases
│           │   └── DataTests/
│           ├── Store/
│           │   ├── Domain/           # ServerStoreDomain: Store protocol, records
│           │   ├── Data/             # ServerStoreData: JSON document, atomic replace
│           │   └── DataTests/
│           ├── Watch/
│           │   └── Data/             # ServerWatchData: FSEvents union watcher
│           ├── Api/
│           │   ├── Presentation/     # ServerApiPresentation: Hummingbird routes, TLS, auth, SSE
│           │   └── PresentationTests/
│           ├── Mac/
│           │   ├── Ui/               # ServerMacUi: menu, settings tabs, pairing QR. Stateless views
│           │   └── Presentation/     # ServerMacPresentation: scenes, view models, composition root
│           └── Cli/
│               └── Main/             # granita-server executable, composition root
├── Apps/
│   ├── GranitaMac/                   # @main shell + Info.plist + entitlements
│   └── GranitaMobile/                # @main shell + Info.plist
├── Scripts/
│   ├── make-fixture-repo.sh
│   └── make-app-icons.py
└── SPEC.md
```

**Module naming.** A target's module name is its path with the slashes removed:
`Client/Viewer/Data` → `import ClientViewerData`. Every target declares an explicit `path:` in
`Package.swift`; there is no `Sources/` wrapper. Test targets sit beside the module they test as
`<Layer>Tests` (`Client/Viewer/DomainTests` → `ClientViewerDomainTests`).

**Layer rules (following Oltre), enforced by the target dependency graph so the compiler polices
them:**

- A `Domain` target depends only on other `Domain` targets and Foundation. No frameworks, no I/O.
- A `Data` target depends on `Domain` targets (its own feature's and others') plus at most **one**
  declared infra dependency, listed in §2.
- A `Ui` target holds **stateless SwiftUI views only**: each takes what it renders and reports what
  happened, through initialiser parameters and closures. It depends on `Domain` for the model types
  it renders and on SwiftUI. It owns no view model, imports no `Presentation` and no `Data`, and
  contains no logic a test would want to reach — so it has no test target.
- A `Presentation` target holds **view models, mappers and screen composition**. It depends on its
  feature's `Ui` and on `Domain` targets, and never on a `Data` target.
- **`Presentation` depends on `Ui`, not the other way round** (Davide, 2026-08-19). `Ui` is the
  inner of the two view layers. A view that imported its view model could only ever serve the one
  screen that view model belonged to; a view that takes values and closures serves any screen that
  has them. It follows that `Presentation` sees SwiftUI transitively, which is a change from an
  earlier draft of this section.
- Only the three **composition roots** import `Data` targets and wire implementations into
  protocols: `ClientAppPresentation`, `ServerMacPresentation`, and `Server/Cli/Main`. Both app roots
  are `Presentation` modules, because under the rule above a `Ui` module could not reach a `Data`
  target even if it wanted to.
- `Server/Api/Presentation` is the server's presentation layer in the same sense, domain-to-wire
  mapping plus routes. The server API has no `Ui` sibling, since it has no views.
- Platform split: `Core/*` compiles for iOS and macOS, `Client/*` is exercised on iOS and iPadOS,
  `Server/*` is macOS only. Enforced by what each app shell links and by CI building both slices.

---

## 4. Domain model (`CoreDiffDomain`)

Every type is `Sendable`, `Codable`, `Hashable`. Identifiers are **opaque**: the client never sends
or receives a filesystem path as an addressable parameter, see §8.

```swift
struct ProjectID: Hashable, Codable, Sendable  { let rawValue: String }
struct WorktreeID: Hashable, Codable, Sendable { let rawValue: String }
struct FileID: Hashable, Codable, Sendable     { let rawValue: String }

struct Project {
    let id: ProjectID              // SHA-256 of the canonical repo path, 32 hex chars
    let name: String               // last path component by default, user overridable
    let isVisible: Bool
    let worktreeCount: Int
    let dirtyWorktreeCount: Int
}

struct Worktree {
    let id: WorktreeID             // SHA-256 of the canonical worktree path, 32 hex chars
    let projectID: ProjectID
    let projectName: String
    let branch: String?            // nil when detached
    let isPrimary: Bool            // the main checkout, not a linked worktree
    let isDetached: Bool
    let isLocked: Bool
    let hasUnbornHead: Bool
    let alias: String?             // user set, wins over everything
    let suggestedAlias: String?    // derived from the Claude Code session, §7
    let displayName: String        // alias ?? suggestedAlias ?? branch ?? directoryName
    let directoryName: String
    let isPinned: Bool
    let stats: ChangeStats
    let lastModified: Date
    let revision: String           // SHA-256 of the raw porcelain v2 bytes
}

struct ChangeStats { let filesChanged: Int; let insertions: Int; let deletions: Int }

enum FileStatus: String, Codable, Sendable {
    case added, modified, deleted, renamed, typeChanged, untracked, conflicted
}

struct FileChange {
    let id: FileID                 // SHA-256 of the repo-relative path bytes, 32 hex chars
    let path: String               // repo relative, POSIX separators
    let oldPath: String?           // set for renamed
    let status: FileStatus
    let isBinary: Bool
    let isSubmodule: Bool
    let stats: ChangeStats
    let contentHash: String        // see §5.5, 64 hex chars
    let estimatedLineCount: Int    // diff lines, used by the client to reserve scroll space
    let isViewed: Bool
    let isTruncated: Bool
    let language: String?          // inferred from the extension, hint for the highlighter
}

struct FileDiff {
    let file: FileChange
    let hunks: [Hunk]
    let oldLineCount: Int          // total lines in the HEAD version, enables canExpandDown
    let newLineCount: Int          // total lines in the working copy
    let isTruncated: Bool
    let truncationReason: String?
}

struct Hunk {
    let index: Int
    let oldStart: Int; let oldCount: Int
    let newStart: Int; let newCount: Int
    let sectionHeading: String?    // text git puts after the closing @@
    let lines: [DiffLine]
}

enum DiffLineKind: String, Codable, Sendable {
    case context, addition, deletion, noNewlineMarker, conflictMarker
}

struct DiffLine {
    let kind: DiffLineKind
    let oldNumber: Int?
    let newNumber: Int?
    let text: String               // without the leading +/-/space
    let displayColumns: Int        // tab-expanded, East-Asian-width aware. §10 uses this
    let segments: [WordSegment]?   // populated only for paired add/delete lines
}

struct WordSegment { let text: String; let isChanged: Bool }
```

`FileStatus.copied` is deliberately absent: copy detection needs `--find-copies`, which is expensive,
and we do not pass it.

---

## 5. Git layer (`ServerGitDomain` + `ServerGitData`)

### 5.1 Invocation rules

Davide has external diff tools and pagers configured globally. Every invocation must be hardened
against his own git configuration.

**Global prefix, on every invocation:**

```
git -c core.pager=cat -c color.ui=false -c core.quotePath=false --no-pager <subcommand> ...
```

**Diff-family suffix, appended only for `diff`, `show`, `log`, `diff-index`, `diff-tree`:**

```
--no-ext-diff --no-color
```

**TRAP.** `--no-ext-diff` and `--no-color` are **not** universal flags:

```
git status --porcelain=v2 --no-ext-diff        → error: unknown option `no-ext-diff'
git worktree list --porcelain --no-ext-diff    → error: unknown option `no-ext-diff'
git rev-parse --no-color --show-toplevel       → prints "--no-color" as an output line, exit 0
```

The `rev-parse` case is the dangerous one: it does not fail, it silently emits an extra line, so
`--show-toplevel` parsing returns garbage. Build the argument vector per subcommand family and add a
unit test that asserts the **argument array** for each command, not merely that the command
succeeded.

Also, in every child process:

- `GIT_OPTIONAL_LOCKS=0`, so read operations never take the index lock and never fight a running
  Claude Code session. Cost: `git status` cannot write back a refreshed index, so each refresh
  re-stats the worktree. Accept it, and pair it with the per-worktree rate limit in §8.
- `GIT_TERMINAL_PROMPT=0`; clear inherited `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`.
- Always `--` before paths. Always an argument array, never `/bin/sh`.
- Use `-z` NUL separated output wherever git offers it, including `worktree list -z`, and parse bytes
  rather than lines. Paths on disk are bytes, not necessarily valid UTF-8: decode lossily for display
  and keep the raw bytes for re-invocation.
- Resolve the `git` binary once at startup (`/usr/bin/git`, then `xcrun -f git`, then `PATH`) and
  surface a clear error in the Mac UI if it is missing.

**TRAP, process I/O.** A macOS pipe buffer is 64 KiB and our own size guard permits a 2 MB diff. If
the implementation awaits termination before draining, or drains stdout to completion before touching
stderr, git blocks writing and the app blocks waiting: a hard hang on exactly the large diffs the
guards exist for. Drain stdout and stderr **concurrently**, then await exit. Enforce the output cap by
cancelling the drain, not by letting the buffer fill.

**TRAP, timeouts.** `Foundation.Process` gives the child the app's own process group, so
`killpg(getpgid(pid))` would signal the menu bar app itself. Never `killpg`. On a 10 s timeout call
`terminate()` (SIGTERM), wait 500 ms, then `kill(pid, SIGKILL)`.

**TRAP, unborn HEAD.** In a repo with no commits, `git diff HEAD` exits 128 with
`fatal: ambiguous argument 'HEAD'`, while `git status` works fine. This happens with a fresh project
or `git worktree add --orphan`. Resolve `git rev-parse --verify --quiet HEAD` once per worktree
refresh; if it fails, set `hasUnbornHead` and substitute the empty tree object
`4b825dc642cb6eb9a060e54bf8d69288fbee4904` everywhere `HEAD` appears as a revision.

### 5.2 What v1 shows

**LOCKED.** The **uncommitted working state only**: everything between `HEAD` and the working tree,
which covers both staged and unstaged changes, plus untracked non-ignored files rendered as fully
added files. Committed history is out of scope for v1. Ignored files are never shown.

### 5.3 Commands, and the single source of truth rule

**TRAP, two disagreeing sources.** Taking the file list from `git status` and the stats from
`git diff --numstat` runs rename detection twice over different comparisons: status compares
HEAD→index and index→worktree, diff compares HEAD→worktree directly. They disagree routinely. A file
staged as a delete plus an unstaged add is one rename to `diff HEAD` and two entries to `status`,
producing files with no stats, stats with no file, and totals that do not add up.

**Rule: the tracked change set and its stats come from one comparison with identical options.**

| Purpose | Command |
| --- | --- |
| Repo detection | `rev-parse --is-inside-work-tree`, `rev-parse --show-toplevel` |
| Worktrees | `worktree list --porcelain -z` |
| Current branch | `rev-parse --abbrev-ref HEAD` (literal `HEAD` means detached) |
| Unborn HEAD check | `rev-parse --verify --quiet HEAD` |
| Tracked paths and status | `diff HEAD -z -M --raw` |
| Tracked stats | `diff HEAD -z -M --numstat` (same `-M` threshold) |
| Untracked paths | `ls-files --others --exclude-standard -z` |
| Worktree revision, conflicts | `status --porcelain=v2 -z` (used for nothing else) |
| Tracked file diff | `diff HEAD -U<context> -- <path>` |
| Untracked file diff | `diff --no-index -U<context> -- /dev/null <path>` |
| Old side of a file | `show <HEAD>:<path>` |
| Content hashing | `hash-object --stdin-paths` (batched) |

**TRAP, `--no-index` exit code.** `git diff --no-index` exits 1 when differences exist. That is
success. For diff-family subcommands, treat exit 0 and 1 as success and only 2 and above as errors.

**TRAP, two different `-z` rename layouts, with opposite path order.**

```
status --porcelain=v2 -z --renames
  2 RM N... 100644 ... R100 <newPath>NUL<oldPath>NUL        ← NEW path first

diff --numstat -z -M
  <added>TAB<deleted>TAB NUL <oldPath> NUL <newPath> NUL    ← rename: OLD then NEW
  <added>TAB<deleted>TAB<path> NUL                          ← non-rename form
```

**Corrected 2026-08-20, verified against the committed fixture.** An earlier draft of this section
said `--numstat -z` emits "an extra empty field" before the paths on a rename, and that a parser
should detect the rename form by that empty field. It does not, and there is **no zero-length NUL
field anywhere in the stream**. What marks a rename is a **trailing TAB** inside the first field —
`1\t1\t` rather than `1\t1\tplain.txt` — so the record spans three NUL fields instead of one. A
parser scanning for an empty NUL field finds none and reads every rename as an ordinary record.

The hazard the old wording pointed at is real: records occupy a **variable number of NUL fields**, so
a naive whole-buffer split desynchronises for the rest of the stream at the first rename. Consume
field by field: if the field ends with a TAB, two more fields follow and they are old then new.
Copying the porcelain-v2 field order here reverses every rename, because that format emits NEW
first. Test both layouts explicitly.

**TRAP, conflicted files.** `status --porcelain=v2` unmerged records start with `u` and carry **10**
fields, not 8:

```
u UU N... 100644 100644 100644 100644 <h1> <h2> <h3> f.txt
```

A field-count parser written for `1` and `2` records will consume into the next record. Claude Code
runs rebases and merges, so this will happen. `git diff HEAD` on a conflicted path emits a **normal**
unified diff containing `<<<<<<<`, `=======`, `>>>>>>>` markers, not a combined `diff --cc`, so §6's
parser needs no combined-diff support; instead the parser tags those lines as `.conflictMarker` and
the client renders them distinctly.

### 5.4 Size guards

- A single file diff above 20,000 lines or 2 MB returns `isTruncated: true` with the first 2,000
  lines only.
- A worktree with more than 1,000 changed files returns a truncated list with a clear flag.
- Binary and submodule entries are listed with stats but never carry hunks.

### 5.5 Content hashing

```
contentHash = SHA-256( status ‖ headOID ‖ indexOID ‖ worktreeBlobOID )   → 64 hex chars
```

`worktreeBlobOID` comes from a single batched `git hash-object --stdin-paths` over the changed paths;
for a deleted file it is the all-zero OID. Never read and hash file bytes yourself: a 1,000 file
worktree refreshing every 400 ms would be real I/O. `FileID` is SHA-256 of the repo-relative path
bytes truncated to 32 hex chars. `revision` is SHA-256 of the raw porcelain v2 bytes.

---

## 6. Unified diff parser (`CoreDiffDomain`) and word diff

The highest risk component in the product. Build it **first**, test first, with golden fixtures,
before any server or UI code exists.

Must handle: `diff --git` headers with spaces and non-ASCII in paths; `old mode` / `new mode` and
mode-change-only files with no hunks; `new file mode` and `deleted file mode`; `similarity index`
with `rename from` / `rename to`; `Binary files a/x and b/x differ` and `GIT binary patch`;
`--- /dev/null` and `+++ /dev/null`; hunk headers with omitted counts (`@@ -1 +1 @@`,
`@@ -0,0 +1,5 @@`); the optional section heading after the closing `@@`; `\ No newline at end of
file` on either side; CRLF preserved verbatim in `text`; submodule diffs (`Subproject commit ...`);
conflict marker lines; empty diffs.

**Fixtures.** `Scripts/make-fixture-repo.sh` builds a deterministic repo exercising every case above,
plus an unborn HEAD repo, a conflicted merge, a linked worktree created **outside** the repo root,
and a worktree under `.claude/worktrees/`. Tests run the real `git` binary against it and assert on
parsed output. The resulting `.diff` files are committed as golden fixtures too, so parser tests can
also run without git.

### `displayColumns`

Computed in the parser, per line, and carried in the model because §10 depends on it: tabs expand to
the next multiple of 4, East Asian Wide and Fullwidth characters count 2, combining marks count 0,
everything else counts 1. Lines containing anything outside that predictable set (emoji, ZWJ
sequences, unusual scripts) set `displayColumns` to the best-effort value **and** set
`DiffLine.needsMeasurement`, so the client falls back to real text measurement for those lines only,
see §10.

Three points the original rule left open, settled 2026-08-20:

- **`DiffLine` carries `needsMeasurement`.** §4's model had no field for the flag this paragraph and
  §10 both rely on, so the client had no way to know which lines to measure. It is a plain `Bool`
  rather than an optional, because an absent key meaning false is the same ambiguity §8's PATCH body
  already has to work around.
- **Control and format characters (Unicode Cc/Cf) count 0**, not 1. Read literally, "everything else
  counts 1" gives `first\r` six columns for a line that occupies five, so every CRLF line would
  over-measure. CRLF is preserved verbatim in `text`, so the CR is content — it simply renders
  nothing.
- **East Asian *Ambiguous* characters count 1 and are not flagged.** `è` and `—` are Ambiguous, they
  are narrow in the monospaced fonts the viewer uses, and flagging them would push ordinary European
  prose onto the slow measured-for-real path.

### Word level diff

1. Within a hunk, collect maximal runs of consecutive deletions immediately followed by additions.
2. Pair positionally, i-th deletion with i-th addition. Unpaired lines get no segments.
3. Skip if similarity is below 0.4 or either line exceeds 1,000 characters. It is noise and it is slow.
4. Tokenise into words, punctuation runs and whitespace runs as separate tokens, run an LCS over
   tokens, emit `[WordSegment]` for both sides. Because whitespace runs are their own tokens, a pure
   indentation change already isolates correctly with no special case.

---

## 7. Worktree aliases from Claude Code sessions

Resolution order: `alias ?? suggestedAlias ?? branch ?? directoryName`. The alias is set from the
phone. `suggestedAlias` is derived, best effort, and must never block a request.

**Source of truth for worktrees is `git worktree list --porcelain -z`.** Claude Code currently places
worktrees at `<repo>/.claude/worktrees/<name>` with branches named `worktree-<name>`, but that is an
implementation detail, not a contract, and `git worktree add` can place a worktree anywhere on disk.
Use the nesting only as an optional hint for labelling a worktree as agent created.

**Session index (`ServerSessionsData`), background task, refreshed on a 30 s timer and on FSEvents:**

- Root is `CLAUDE_CONFIG_DIR` if set, else `~/.claude`. Enumerate `projects/*/*.jsonl`. Handle a
  missing directory silently.
- Read only the **first 64 KB** and the **last 64 KB** of each file. These reach tens of megabytes and
  must never be fully loaded. **Discard the last partial line of the head chunk and the first partial
  line of the tail chunk** before parsing, or you will feed truncated JSON to the decoder.
- `cwd` is present on every record, not only the first, and there is a `gitBranch` field: use it as a
  tiebreaker when several sessions share a directory.
- Match worktree to session by **longest path prefix**, not exact equality, since a session may have
  started in a subdirectory. Sort candidates by mtime descending.
- Label: prefer the most recent `summary` typed record from the tail, else the first `user` record's
  text from the head. Collapse to one line, strip markdown, truncate to 60 characters on a word
  boundary.
- Cache per file keyed by (path, mtime, size). Never re-read an unchanged file.
- The directory name under `projects/` is a slugified cwd whose exact encoding is **not documented**.
  Never reconstruct it. Always read `cwd` out of the file contents.
- Privacy note: this surfaces conversation text over the LAN. The 60 character truncation is
  deliberate, and `suggestedAlias` must never carry more than that.

**VERIFY:** before implementing, read one real session file on this machine, confirm the record shape
and field names, and record what you found in a comment at the top of the parser.

---

## 8. HTTP API and transport

JSON over HTTPS/1.1. All errors use `{ "error": { "code": "...", "message": "..." } }`.

```
GET   /v1/health                                      no auth
POST  /v1/pair                                        no auth
GET   /v1/projects                                    -> [Project]
GET   /v1/worktrees?projectID=<id>                    -> [Worktree]  (omit param for all)
PATCH /v1/worktrees/{worktreeID}                      -> Worktree
GET   /v1/worktrees/{worktreeID}/changes              -> { revision, stats, files: [FileChange] }
GET   /v1/worktrees/{worktreeID}/diffs?fileIDs=a,b,c&context=3
                                                      -> [FileDiff]   (max 20 ids, max 2 MB)
GET   /v1/worktrees/{worktreeID}/files/{fileID}/diff?context=3
                                                      -> FileDiff
GET   /v1/worktrees/{worktreeID}/files/{fileID}/lines?side=new|old&start=<1-based>&count=<n>
                                                      -> { lines: [String], eof: Bool }  (max 500)
POST  /v1/worktrees/{worktreeID}/files/{fileID}/viewed  body { viewed, contentHash } -> 204
GET   /v1/events                                      -> text/event-stream
```

**Batching, not N+1.** Opening a 40 file worktree must not be 41 round trips each spawning a `git`
process. The client prefetches the next five files in one `/diffs` call. The server computes them
concurrently with a bounded task group, at most four concurrent `git` processes.

**Context expansion is client-owned state.** A single stateless `expandHunk` parameter cannot express
"hunk 2 expanded up and hunk 5 expanded down", which §10 requires. The client fetches raw lines from
`/lines` and splices them into its own hunk model. `FileDiff.oldLineCount` and `newLineCount` make
"can expand down" computable.

**PATCH body.** `{ "alias": String | null, "isPinned": Bool }`, both keys optional, partial update.

**TRAP.** `Codable` decodes a missing key and an explicit `null` identically to `nil`, so a naive
struct cannot tell "clear the alias" from "leave the alias alone". Decode with
`container.contains(.alias)` to detect presence and `container.decodeNil(forKey: .alias)` to detect an
explicit null. Absent means unchanged, null means clear, a value means set. `isPinned` is a plain
`Bool` where absent means unchanged.

**Pair body.** Request `{ code, deviceName, platform }`, response
`{ token, deviceID, serverInstanceID }`, 401 `pairingExpired` on a stale or reused code.

**Health body.** `{ "name": "Granita", "apiVersion": 1, "serverVersion": "1.0.3" }`. The Mac app and
the TestFlight iOS app ship independently, so version skew is guaranteed: the client refuses to pair
and shows "update your Mac app" on `apiVersion` mismatch, and any route returns 426
`unsupportedApiVersion` if the client sends a newer one.

**Error codes**, part of the contract because the client branches on them: `unauthorized`,
`pairingExpired`, `rateLimited`, `projectNotVisible`, `worktreeGone` (410, directory or worktree entry
disappeared), `fileGone` (410), `staleContentHash` (409, returned by `/viewed` when the supplied hash
no longer matches so a stale version cannot be marked viewed), `gitFailure` (500, carries stderr),
`tooLarge` (413), `unsupportedApiVersion` (426).

### Transport and security

- **The API never accepts a filesystem path as an input.** All addressing is by opaque ID resolved
  against the server's own registry. This is the single most important rule in the API: the server
  streams private source code, and a path parameter is a directory traversal hole.
- **TLS, not plaintext.** The server generates a self-signed P-256 identity at first run, stored in
  the login Keychain, ten year validity, SAN covering the Bonjour hostname and every local IP. The
  pairing QR carries `granita://pair?host=&port=&code=&spki=<base64 SHA-256 of the SPKI>` and the
  client **pins that SPKI** in a `URLSessionDelegate` server-trust challenge.
- A custom trust evaluation satisfies App Transport Security, so **no ATS exception is required**.
  Keep `NSAllowsLocalNetworking = YES` only as a declaration of intent. This also unblocks v2:
  `NSAllowsLocalNetworking` covers only unqualified names, `.local` names and IP addresses, so a
  Tailscale MagicDNS host such as `macbook.tail1234.ts.net` would be blocked under plain HTTP. With
  pinning, v2 remote access is a host change and no code change.
- Bearer token on every route except `/v1/health` and `/v1/pair`, constant time comparison. Tokens
  are per device, individually revocable, stored hashed on the Mac and in the Keychain on iOS. The
  one time pairing code expires after 120 seconds and is single use. A six word fallback code is
  shown under the QR for when the camera is unavailable. Reject more than five failed auth attempts
  per minute per source address.
- **Escape hatch.** `granita-server --insecure-http` disables TLS. Off by default, never reachable
  from the UI, and the Mac app shows a warning banner when the running server has it on. It exists so
  a TLS problem can never leave code unreviewable.

### Listening and Bonjour, in one operation

**TRAP.** Do not create a separate `NWListener` to advertise. `NWListener` binds the port, and
Hummingbird binds it too via SwiftNIO; two objects cannot bind the same TCP port, so advertising on
the real port fails and advertising on port 0 publishes the wrong one.

Run the Hummingbird `Application` on a `NIOTSEventLoopGroup` and bind
`BindAddress.nwEndpoint(.service(name: <device name>, type: "_granita._tcp", domain: "local",
interface: nil))`. Hummingbird's `Server.makeServer` routes that through `NIOTSListenerBootstrap`,
which listens and advertises together, and it is the same code path that carries `tlsOptions` for the
TLS identity above. `NWBrowser` on iOS is unchanged. Put `apiVersion` and a stable `serverInstanceID`
in the TXT record so a client can tell its paired Mac from another one.

**TRAP, local network privacy applies to macOS too.** It exists on macOS 15+ and all Bonjour
operations require it, including **registering** a service, so `GranitaMac` needs
`NSLocalNetworkUsageDescription` and `NSBonjourServices` and will show an approval alert on first
advertise. The simulator does not support local network privacy at all, so every discovery and
pairing acceptance criterion must be met **on device**. Handle denial explicitly: `NWBrowser` reports
`kDNSServiceErr_PolicyDenied` (-65570) while `.waiting`, and `NWConnection` reports
`NWPath.UnsatisfiedReason.localNetworkDenied`. Show an onboarding state with a deep link to
`UIApplication.openSettingsURLString`.

### Live updates

**TRAP.** One recursive FSEvents stream per project root does **not** cover linked worktrees. A linked
worktree's `.git` is a file pointing at `<common>/.git/worktrees/<name>`, so its HEAD and index live
under the main repo's gitdir, and a worktree created outside the repo root is not under the watched
path at all.

- Maintain one `FSEventStreamCreate` over the **union** of: every visible project root, every worktree
  path from `git worktree list --porcelain -z`, and every per-worktree gitdir
  (`<common>/.git/worktrees/<name>`). Rebuild the stream when the worktree list changes.
- Watch `HEAD`, `index`, `MERGE_HEAD`, `REBASE_HEAD` under **any** gitdir. Ignore all other `.git`
  internals.
- Filter `node_modules`, `.build`, `DerivedData`, `Pods`, `target`, `dist` before debouncing.
- Debounce 400 ms, coalesce per worktree, and **rate limit `git status` to at most once per 2 s per
  worktree** regardless of event volume, or a webpack watch loop pins a core running status against a
  large repo.
- Recompute `revision` and emit an event only when it actually changed:
  `event: worktree.changed`, `data: { "worktreeID": "...", "revision": "..." }`. Also
  `worktree.list.changed` when worktrees appear or disappear.
- Heartbeat comment every 20 s. Each event carries an `id:`; honour `Last-Event-ID` on reconnect, or,
  if that is not implemented, state in the client that it re-fetches `/changes` for the visible
  worktree on every reconnect. iOS suspends the app and the stream dies, so reconnect on
  `scenePhase == .active` and reconcile. Never assume the stream survived backgrounding.

---

## 9. macOS app (`GranitaMac`)

Menu bar only (`LSUIElement`), no Dock icon, no main window. The server runs in-process. Views live
in `Server/Mac/Ui`, view models and mappers in `Server/Mac/Presentation`; the Xcode target is a thin
`@main` shell over `ServerMacPresentation`, the composition root.

**Menu bar:** icon reflecting server state, running, stopped or error. **TRAP:** `MenuBarExtra`'s
label reliably renders only `Text` and `Image`, so the dirty-worktree count is a `Text("\(n)")`
beside the icon, not a badge modifier. Menu items: status line showing `host:port`, "Pair a device",
"Open Settings", "Quit".

**TRAP, opening Settings from a `MenuBarExtra` under `LSUIElement`** is a known multi-hour trap:
`SettingsLink` is unreliable inside `MenuBarExtra`, `@Environment(\.openSettings)` fails silently
without an existing render tree, and `NSApp.sendAction(showSettingsWindow:)` is deprecated. Implement
the known working pattern: a hidden 1×1 `Window` declared **before** the `Settings` scene that holds
`openSettings`, plus temporarily switching `NSApp.setActivationPolicy(.regular)` and back. The same
activation dance is needed before presenting `NSOpenPanel`. §14 item 5 is "implement and verify this
pattern", not "check whether it works".

**Settings window, four tabs:**

1. **General.** Port, default 8737, automatic fallback if taken, chosen port persisted. Launch at
   login via `SMAppService.mainApp.register()`. Server state with a restart button.
2. **Projects.** **LOCKED: nothing is visible to the phone unless it is explicitly enabled.** "Add
   project" opens `NSOpenPanel` and adds one repository. Optionally point at a root folder, in which
   case the app lists the git repositories it finds there **as candidates only, all disabled by
   default**. Scanning skips `node_modules`, `.build`, `DerivedData`, `Pods`, `vendor`, `target`, and
   does not descend into a repository once found. Per project: enable toggle, display name, remove.
3. **Devices.** Paired devices with last-seen timestamps and revoke. The pairing QR.
4. **Advanced.** Log level, "Reveal data folder in Finder", "Reset all data", resolved `git` path, and
   a **connection log** showing the last 50 connection attempts with the exact TLS or auth failure
   reason. That panel is not optional: it is what makes a phone that will not connect debuggable
   without attaching a debugger.

**Persistence.** A single JSON document at
`~/Library/Application Support/Granita/store.json`, owned by one actor, written with atomic replace
(write to a sibling temp file, then `FileManager.replaceItemAt`). Never partial-write in place.

```swift
struct StoreDocument: Codable, Sendable {
    var schemaVersion: Int             // bump and migrate in code, keep the old decoder
    var projects: [StoredProject]      // id, path, name, isEnabled, addedAt, bookmark
    var worktreeSettings: [StoredWorktreeSettings]  // worktreeID, path, alias, isPinned, updatedAt
    var viewedFiles: [StoredViewedFile]             // worktreeID, fileID, contentHash, viewedAt
    var devices: [StoredDevice]                     // id, name, tokenHash, platform, dates
}
```

- Held fully in memory, flushed on change with a 1 s coalescing debounce plus a flush on termination.
- `viewedFiles` is keyed by **content hash**, so a file marked viewed becomes unviewed automatically
  when the agent changes it again. That behaviour is the point of the feature. Do not key on path
  alone.
- `viewedFiles` is the only unbounded collection. Prune on startup: drop entries whose worktree no
  longer exists, and cap at 20,000 entries by dropping the oldest.
- The store is behind a `Store` protocol with the JSON implementation as the only conformer, so v2 can
  swap in something else if comments make the data grow.
- A lock file next to the store prevents a standalone `granita-server` and the menu bar app from both
  holding it. The second one to start refuses with a clear message.

**TRAP, restarting the server.** A ServiceLifecycle `ServiceGroup` cannot be restarted after
cancellation. "Stop and start from the menu" means constructing a **new** `Application` and
`ServiceGroup` each time, holding the `Task` handle, and awaiting its completion before rebinding.

**Wake from sleep.** Observe `NSWorkspace.didWakeNotification` and re-bind plus re-advertise. A
laptop that slept is the single most likely reason the phone cannot reach the server.

---

## 10. iOS and iPadOS app (`GranitaMobile`)

Universal, `NavigationSplitView`, real three column layout on iPad, adaptive stack on iPhone. Every
feature lives under `Client/` in the package; the Xcode target is a thin shell importing
`ClientAppPresentation`, which is the composition root.

### Structure

- **Sidebar: worktrees.** Segmented control switching between **grouped by project** and **flat, most
  recently changed first**. Each row: display name, project name, changed file count, `+n / -m`,
  relative timestamp, and a pin indicator when pinned. Swipe actions: rename, which opens a sheet with
  the suggested alias prefilled and a "use suggestion" button, and pin or unpin. Renaming writes the
  alias only and never touches git.
- **Pinning.** Pinned worktrees sort above everything else in both modes. In grouped mode they form a
  single "Pinned" section at the top, above the per-project sections, rather than floating to the top
  of their own project. Pin state lives on the Mac, so it is the same on iPhone and iPad.
- **Content: file selector.** Directory grouped, Android Studio style, including **compaction of
  single child directory chains** into one row (`app/src/main/kotlin/com/example` renders as one row,
  not five). Per row: status letter with semantic colour, file name, `+n / -m`, viewed checkbox.
  Directories collapse and remember state per worktree. A toggle switches to a flat path list.
  Tapping a file scrolls the diff to it. On iPhone this is a `.sheet` at medium and large detents,
  reachable from a toolbar button, so it is one tap away at all times.
- **Detail: the diff, one continuous scroll across every file.**

### The continuous scroll, and how wrap stays possible

**LOCKED: one continuous scroll over all files, with a wrap toggle.**

**TRAP.** Lazy stacks estimate the size and offset of off-screen views. When a placeholder becomes
real content and its height changes, everything after it shifts. If that happens **above** the
viewport, the visible content jumps under the user's finger. This is the defect that kills naive
implementations.

The resolution is ordering, not fixed heights:

- **Loading is strictly append only.** Files are fetched in document order, five ahead of the
  viewport. Content is never inserted or resized above the current scroll position. Height estimation
  error below the viewport is invisible, so estimates only need to be reasonable, not exact.
- **Measured heights are sticky.** Once a file's real height is known it is cached for the session,
  keyed by `(fileID, contentHash, wrapMode, availableWidth, fontSize)`, and a recycled file never
  reverts to its estimate. Scrolling back up therefore never reflows.
- **Estimates** come from `estimatedLineCount` times the line height, and in wrap mode from a per-file
  estimate the server can compute cheaply.
- **Wrap off**, the default: one row per diff line, long lines scroll horizontally within the file
  with the gutter pinned.
- **Wrap on:** rows per line is `max(1, ceil(displayColumns / columnsPerRow))` where `columnsPerRow`
  is `floor(availableWidth / advanceWidth)` for the monospaced font, and `displayColumns` comes from
  the parser, §6. This is exact **only if wrapping breaks on characters rather than words**, so the
  text view must use `NSLineBreakMode.byCharWrapping`. Xcode wraps mid-token too, so this matches what
  a code editor does. Lines the parser flagged as unpredictable are measured for real and cached.
- **Toggling wrap, rotating, or changing font size** invalidates cached heights. Capture the top
  visible `(fileID, lineIndex)` first, relayout, then restore that anchor. Never preserve
  `contentOffset` across a mode change.
- Scroll position is tracked with `onScrollTargetVisibilityChange`, never with `contentOffset`.
- **Focus mode** stays available: tapping a file header opens that single file in a `NavigationStack`
  detail with prev and next controls. On iPad the third column is this same view. It is a convenience,
  not the fallback for a broken continuous mode.

**VERIFY, and report the numbers:** that `byCharWrapping` is achievable in the chosen text rendering
path, and that computed heights match measured heights within 0.5 pt across the fixture corpus. If
they do not, the arithmetic is wrong and that must be known before the UI is built on it.

### Diff rendering requirements

- Hunks are fetched lazily through the batched `/diffs` endpoint, five files ahead. The changes list
  endpoint returns stats only, never hunks.
- Files marked viewed render collapsed. Files over 500 diff lines start collapsed with a "Load diff"
  affordance.
- **Collapsed context:** three lines around each hunk, an expand control on every hunk header,
  "expand all" per file, all fed by the `/lines` endpoint with the client owning expansion state.
- **Word level highlighting** from the server supplied segments, as a stronger background on the
  changed spans over the line level add/remove background.
- **Syntax highlighting per file, per side, never per hunk.** A hunk starting inside a class body, a
  multi-line string or a heredoc gives the lexer no opening context and mis-lexes the whole block,
  which is the same failure that highlighting line-at-a-time produces. Concatenate all old-side lines
  (context plus deletions) of the file in order into one string and highlight once; same for the new
  side; split back by newline and index into the hunks. Cache key
  `(fileID, contentHash, side, language, colorScheme, fontSize)`. Skip entirely when a side exceeds
  100 KB or 4,000 lines, or when `language` is nil, and render plain monospaced text. Highlight the
  visible file first and never speculatively highlight unopened files. Render unhighlighted first and
  upgrade in place.
- **Gutter** with old and new line numbers, monospaced tabular figures, fixed width.
- **Colours:** semantic, full light and dark. A settings toggle for a colourblind safe palette, blue
  and orange instead of green and red.
- **Code font size** adjustable in settings, independent of Dynamic Type, which still governs all
  surrounding chrome.
- **Live updates:** never re-scroll or reflow under the reader's finger. If the worktree changes while
  scrolled into content, show a "Changes available" pill that applies on tap. Pull to refresh always
  works.

### Connection

- Bonjour discovery of `_granita._tcp` so no IP typing, with manual host entry as fallback, and always
  re-resolve via Bonjour before falling back to the stored address, since the server's port can change.
- QR pairing with `AVFoundation`, SPKI pinning, token in the Keychain. Info.plist needs
  `NSLocalNetworkUsageDescription`, `NSBonjourServices = ["_granita._tcp"]`, `NSCameraUsageDescription`.
- **Demo mode**, PROPOSED and cuttable: a bundled fixture dataset so the app runs with no Mac present,
  for UI work and screenshots. If kept, wire it behind the same repository protocol as the live client
  so it is not a special case in the views.

---

## 11. Explicit v1 scope

**In:** projects added explicitly, worktrees, aliases with Claude session derived suggestions,
pinning, grouped and flat worktree lists, directory grouped file selector with path compaction,
continuous diff of uncommitted changes across all files with a wrap toggle, per-file focus mode,
syntax highlighting, word level intra line diff, mark file as viewed, collapsed context with
expansion, live updates, Bonjour plus QR pairing over TLS with SPKI pinning, LAN only, universal
iPhone and iPad, light and dark.

**Out, v2 backlog. Design so these stay cheap, build none of them:**

- inline comments, line and range, with threads
- feedback export: `REVIEW.md` written into the worktree, iOS share sheet, clipboard, and injection
  straight into the Claude Code session
- push notifications when an agent finishes, via a Claude Code `Stop` hook posting to the Mac server,
  which then hits APNs
- remote access over Tailscale, already unblocked by the TLS decision, host change only
- committed history browsing, staged versus unstaged split, discarding a hunk, pruning worktrees
- Mac App Store build on a libgit2 `GitClient`

**Known unknown, flagged now:** injecting a prompt into a session that is live under `claude rc` is
undocumented. Concurrent `claude --resume` on an attached session may fork, queue, error or corrupt
state. Spike it in isolation before building it, and treat writing `REVIEW.md` as the reliable
fallback.

---

## 12. Milestones

**LOCKED: stop for review at every boundary.** Each milestone ends with something runnable and a green
test suite. Commit after each green-refactor cycle.

- **M0. Scaffold.** Repo layout, `project.yml`, `Makefile`, CI on a macOS runner with a pinned Xcode
  version, every target in the §3 manifest and both app shells building empty,
  `Scripts/make-fixture-repo.sh` producing the fixture repos from §6. Acceptance: `make test` passes
  on a clean checkout.
- **M1. Core.** `CoreDiffDomain` models, unified diff parser, `displayColumns` and word diff;
  `CoreTreeDomain` grouping with path compaction. Tests only. Acceptance: every case in §6 covered by
  a golden fixture test.
- **M2. Server.** `ServerGitDomain`/`ServerGitData` (`GitClient`, `ProcessGitClient`),
  `ServerWorktreesDomain` enumeration, status and diff services with hashing and size guards,
  `ServerStoreDomain`/`ServerStoreData` JSON store with migration support, `ServerSessionsData`,
  `ServerApiPresentation` REST API with TLS and auth, and the `granita-server` executable
  (`Server/Cli/Main`) with `--add-project`, `--issue-token` and `--insecure-http` so the whole thing
  is testable from a terminal. Acceptance: integration tests drive the real git binary against the
  fixture repos, and `curl` against a running `granita-server` returns correct JSON for every endpoint
  including the rename, conflict and unborn-HEAD cases.
- **M3. GranitaMac.** `ServerMacUi`, `ServerMacPresentation` and the shell: menu bar app, Settings
  with explicit project enabling, Bonjour advertising through the Hummingbird NIOTS bind, pairing with
  QR, login item, embedded server, TLS identity in the Keychain, connection log panel,
  wake-from-sleep rebind. Acceptance: pair from a real device on the LAN and hit the API.
- **M4. GranitaMobile, part one.** `ClientConnection*` and `ClientWorktrees*`: pairing with SPKI
  pinning, Bonjour discovery, worktree list grouped and flat, aliases with suggestions, pinning,
  local-network-denied state. Acceptance: on device, not the simulator.
- **M5. GranitaMobile, part two.** `ClientViewer*`: file selector with compaction, continuous scroll
  with the wrap toggle and sticky measured heights, focus mode, batched lazy loading, syntax
  highlighting, word diff rendering, viewed state, context expansion, settings. Acceptance: scrolling
  the 40 file fixture worktree end to end on an iPhone, in both wrap modes, produces zero frames over
  8 ms in an Instruments Animation Hitches trace. "No stutter" is not a testable criterion.
- **M6. Live and ship.** FSEvents union watching, SSE with reconnect and reconciliation, the "changes
  available" pill, polish, accessibility pass, a run against the current iOS beta, TestFlight.

---

## 13. Engineering standards

- **TDD is not optional.** Failing test first, minimum implementation to pass, then refactor. The diff
  parser and the git layer are written test first, no exceptions.
- **Strong typing.** No stringly typed identifiers, no untyped dictionaries crossing a boundary, no
  `Any`. Use the opaque ID types from §4 everywhere.
- **Boundaries.** The layer rules in §3 are the boundary system, and the target graph makes the
  compiler enforce them. A view never sees `URLSession`; a view model never sees SwiftUI; a domain
  type never sees either.
- **Dependency inversion at every I/O edge.** `GitClient`, `Store`, and the client-side repository are
  protocols with hand-written fakes in tests. No mocking framework.
- **Explicit error handling.** Typed error enums, no swallowed errors, no `try?` to silence a warning.
  A failed git invocation surfaces with its stderr.
- **Naming is documentation.** No abbreviations.
- **Small commits**, one per green-refactor cycle, message says why.
- **Concurrency.** Swift 6 strict concurrency, actors where shared mutable state exists, no
  `@unchecked Sendable` without a written justification in a comment.
- **No dead code, no speculative abstraction.** The only v2 hooks in v1 are the three protocols above.

### Reference projects: Oltre and Aura (LOCKED)

**Oltre** (primary reference) and **Aura** are the reference for how Davide runs Apple projects.
Where this spec explicitly overrides them, the spec wins; everywhere else, do it the way they do it.
If a practice exists in only one of the two, follow that one; if they disagree, ask.

Follow them for, at minimum: CI setup, GitHub repository rules, screenshot tests, coverage reports,
and the Claude Design handoff flow. What was found and adopted is recorded in
`.claude/docs/decisions.md`.

---

## 14. Verify first, before writing any code, and report findings

1. Hummingbird 2's current router, `ServiceLifecycle` integration, `BindAddress.nwEndpoint`, and
   `ServerConfiguration(tlsOptions:)` under `NIOTSEventLoopGroup`, on the current release.
2. swift-subprocess's current API and its Swift 6 strict concurrency behaviour.
3. Highlightr's current API, and **measure** time to highlight a 200 line Swift block on device. If
   p95 exceeds 30 ms, cap highlighting by file size and report the number measured.
4. `git --version` locally, then confirm the exact field layouts in §5.3 against it, including `u`
   records and both `-z` rename forms.
5. Implement and verify the `MenuBarExtra` plus `Settings` pattern under `LSUIElement` described in
   §9, and `SMAppService` login item registration, on macOS 26.
6. Read one real Claude Code session JSONL and confirm §7's record shape. Record it in a comment.
7. XcodeGen's current spec format for one project with a macOS target and a universal iOS target,
   both consuming a local SPM package.
8. Confirm the self-signed identity plus `URLSessionDelegate` pinning path satisfies ATS on the
   current iOS release, and that a custom trust evaluation needs no Info.plist exception.
9. The `byCharWrapping` and height arithmetic check from §10, with numbers.
10. Confirm the GitHub hosted macOS runner image carries the required Xcode and iOS simulator runtime,
    or add `xcodebuild -downloadPlatform iOS` to CI.

---

## 15. What Davide needs to set up

1. Apple Developer Program membership, active.
2. **Developer ID Application certificate** for signing the Mac app, needed even in development
   because local network privacy tracks identity by code signature.
3. Bundle identifiers registered: `dev.fardavide.granita.mac` and `dev.fardavide.granita.mobile`.
4. An App Store Connect app record and an internal TestFlight tester group for the iOS app.
5. Apple's GitHub app installed on the repository, and the Xcode Cloud workflows created in
   Xcode.app — neither can be done from a CLI or an API.
6. `brew install xcodegen`.
7. The first project folder to add.
