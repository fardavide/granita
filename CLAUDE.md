# Granita — agent guide

Granita lets Davide **read the code an agent wrote, from his phone**. A macOS menu bar app
enumerates the git worktrees of projects he has explicitly enabled, computes their uncommitted
diffs, and serves them over the LAN; a native iOS and iPadOS app renders them with the ergonomics of
a real review tool. v1 is read-only apart from worktree aliases and pins. It is not a git client and
it is not a history browser.

## Read first

- **Before any non-trivial change**, read `.claude/docs/architecture.md` and
  `.claude/docs/decisions.md` so you do not break a layer boundary or re-open something settled
  (`.claude/docs/README.md` indexes them). **Keep them current**: decisions in `decisions.md`, where
  we are in `status.md`. Docs are the *why*; skills are actionable rules.
- **`SPEC.md` is the specification.** Its paragraphs marked TRAP describe defects found by running
  things, not by reading documentation — do not simplify them away. `decisions.md` records every
  place this repository knowingly departs from it.
- **Both halves are designed.** `.claude/docs/design.md` is the authority on what the phone and the
  iPad look like, `.claude/docs/design-mac.md` on the menu bar app's seven surfaces, and the
  `/design` skill is binding before any SwiftUI in either. A design question is not an open question
  — look it up rather than inventing a screen. The Mac frames were drawn against 0.0.6 and the sheet
  corrects them for 0.0.7; trust the sheet.
- **Never ship a control that does nothing.** Every row, button and link a reader can press must do
  something they can perceive, *before* the screen ships. It ships only if it works, is absent, is
  disabled **and** says why, or explains that what is behind it is not built. **Mid-slice is not an
  excuse — it is the case the rule is for**, and this layer graph hides it best, because each layer
  looks finished on its own. Granita shipped one for eight releases: discovery's rows linked to a
  destination no module declared, so tapping a Mac did nothing (`decisions.md`). **The only check
  that works is running the app and pressing the thing** — the snapshot suite photographed that row
  in four layouts and stayed green throughout.
- **Invoke applicable skills before acting.** If none apply, say so.

| Skill | Use it for |
|---|---|
| `/architecture` | The module tree, which layer may import which, composition roots, typed identifiers, adding a dependency |
| `/design` | **Any client SwiftUI** — which screen, which control, what truncates which way, what an empty state may offer |
| `/swift-style` | Swift 6 and SwiftUI conventions — concurrency, optionality, typed errors, naming, member ordering |
| `/design-handoff` | Anything a reader looks at: the round trip to Claude Design, and the rule that **no pull request touching a screen opens before its frames exist** |
| `/swift-testing` | Swift Testing, the Scenario fixture, handwritten fakes, the golden diff corpus |
| `/git-invocation` | Running `git` — argument vectors, `-z` parsing, and the six behaviours that are not obvious |
| `/generated-files` | The Xcode project, the diff fixtures and the icons: how to regenerate, what CI gates |
| `/versioning` | Version bumps, the changelog, and the fact that merging publishes |
| `/build-and-test` | The sanctioned build and test commands, and how to land a change |

Global skills also apply — `tdd`, `typing`, `test-doubles`, `scenario-pattern`, `refactor`,
`architecture-review`. Prefer a global skill for language-general rules; add a project skill only
for something specific to Granita.

## Tech stack (decided — do not substitute)

- Swift 6 language mode, strict concurrency `complete`, every target. iOS 26 / iPadOS 26 / macOS 26.
- SwiftUI throughout: `MenuBarExtra` under `LSUIElement` on the Mac, `NavigationSplitView` universal
  on the phone and iPad. `@Observable`, never `ObservableObject`.
- Hummingbird 2 on a `NIOTSEventLoopGroup`, so listening and Bonjour advertising happen in one bind.
- The `git` **binary** via swift-subprocess, behind a protocol. Not libgit2 — git is the source of
  truth for worktrees and index state and libgit2 diverges exactly there.
- One JSON document, actor-guarded, atomic replace. **No SQLite, no SwiftData, no Core Data.**
- `URLSession` with a custom server-trust evaluation. **No Alamofire.** No DI framework, no service
  locator, no mocking framework.
- Testing: **Swift Testing**, not XCTest. TDD.
- **Exactly three external dependencies** — Hummingbird, Highlightr, swift-subprocess — each pinned
  to one target. A fourth is a conversation with Davide before it is a commit.
- The Mac app is **deliberately unsandboxed**: a sandboxed process cannot exec `git` against
  arbitrary folders. That is why every git call goes through a protocol.

## Architecture

One local package holds everything testable; the two Xcode targets are thin `@main` shells linking
one product each. Features are `<Unit>/<Feature>/<Layer>` directories, and a module's name is its
path with the slashes removed (`Client/Viewer/Data` → `import ClientViewerData`).

There is no single chain. Each layer depends on `Domain` and on nothing else in the list:

| Layer | Depends on | Does **not** depend on |
|---|---|---|
| `Domain` | other `Domain` only | everything else |
| `Data` | `Domain` | `Ui`, `Presentation` |
| `Ui` | `Domain`, SwiftUI | `Presentation`, `Data` |
| `Presentation` | `Ui`, `Domain` | `Data` |
| `Main` | anything — it is a composition root | — nothing may depend on **it** |

Enforced by the target graph in `Package.swift`: a dependency a target does not declare does not
compile. `Data` and the two view layers never meet — they are siblings over `Domain`, not a
pipeline.

**`Presentation` depends on `Ui`, not the other way round.** `Ui` is the inner view layer —
stateless views that take what they render and report what happened. `Presentation` owns the view
models and composes screens from them. Only three modules import a `Data` target, because wiring
implementations into protocols is their job: they are the **`Main`** layer — `ClientAppMain`,
`ServerAppMain`, and the `granita-server` executable at `Server/Cli/Main`.

**A `Main` module holds wiring and nothing else.** It is exempt from both coverage rows, so logic
left in one is untested code that no longer looks untested. Move it out and give it a seam.

## Conventions that differ from defaults

- **No consecutive uppercase** in identifiers we define: `Dto`, `Url`, `Http`, `Api`, `Json`, `Id`,
  `Spki`. Apple's own types keep their spelling.
- Test names read `` `given X when Y then Z` `` as backtick raw identifiers.
- No default values in a domain struct's memberwise init — defaults belong in factories.
- No `default:` in a `switch` over an enum. Typed throws with domain error enums at every boundary.
- No tiny rename-only helpers. In docs and skills, describe concepts and contracts, not type names.
- Identifiers are opaque typed wrappers, never unwrapped for convenience. **The API never accepts a
  filesystem path as an input** — that rule is the security boundary, not a style preference.

## Build & test

```bash
make test       # package tests, on the host, no simulator
make build      # compile-check the package and both apps, unsigned
make coverage   # the coverage gate's own verdict, locally — run before any PR that adds code
make snapshots  # render the screens on a simulator against the committed baselines
make run        # run the backend in a terminal
make project    # regenerate Granita.xcodeproj after editing project.yml
```

**The coverage gate is a ratchet with no slack, so any change that adds code can fall under it.**
`make coverage` answers that here instead of twenty minutes later in CI. What to cover as you write
it — every `guard` failure branch, every `??`, every new `case`, every view fallback needs its own
snapshot subject — is in the `swift-testing` skill.

`make record-snapshots` re-records the baselines, and is only ever correct after a deliberate change
to `.claude/docs/design.md`.

- **`main` is PR-gated** by the `protect-main` ruleset: squash only, linear history, four required
  checks, **no bypass for anyone including Davide**. Branch, open a PR, wait for the checks, squash
  merge. `gh pr merge --admin` will fail; the answer is to fix the red check.
- **Merging to `main` publishes.** Every squash merge archives on Xcode Cloud — TestFlight for the
  phone app, notarised Developer ID for the Mac app. A build cannot be un-published.
- If a PR is refused as out of date, run `gh api -X PUT /repos/fardavide/granita/pulls/<n>/update-branch`
  rather than rebasing and force-pushing. The squash flattens the merge commit, so linear history
  still holds, and nothing is rewritten.
- `Granita.xcodeproj` is generated and committed. **Never hand-edit `project.pbxproj`.**

## Sanctioned tooling

**Search with `ast-index` first**, not `grep` — it is far faster and returns structured results, and
`.claude/rules/ast-index.md` has the command table. Fall back to `rg`/`grep` only for regex, string
literals inside code, or comment text, and do not re-run a grep "for completeness" after ast-index
has answered.

The `make` targets above are the only sanctioned path for building and testing, and `xcodegen` via
`make project` the only one for the Xcode project. If one of them fails, **that failure is the
problem to solve** — diagnose it, report it with the exact output, and hand back. Do not route
around it with a raw `xcodebuild`, a hand-edited `pbxproj` or a hand-written fixture to get a change
through, and do not offer that as an option: a blocked change is an acceptable outcome, a bypassed
one is not.
