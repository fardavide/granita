---
name: swift-testing
description: Granita's test conventions — Swift Testing not XCTest, the Scenario fixture, given/when/then structure and names, handwritten fakes over mocking frameworks, and the golden diff fixture corpus.
when_to_use: >
  Use when writing or reviewing test code — adding a @Test, building a Scenario, writing a fake, or
  asserting against a golden fixture. Also when the user asks to "write a test", "add a fake", or
  "test the parser".
---

# Testing

The global `tdd` skill owns the red-green-refactor loop and the global `test-doubles` and
`scenario-pattern` skills own the cross-language rationale. This one owns the Swift shape and what
is specific to Granita.

TDD is not optional here. The diff parser and the git layer are written test first, no exceptions —
they are the two places where a wrong assumption is invisible until a diff renders wrongly on a
phone.

## Framework — Swift Testing, never XCTest

`import Testing`, `@Test`, `#expect`, `#require`. No XCTest anywhere.

Package tests run on the host with no simulator, which is what keeps the loop fast:

```bash
make test
```

## Structure — `// given` / `// when` / `// then`

Each marker appears at most once, in order. When construction itself is the action, use
`// given - when`; when asserting only on state produced by init, omit `// when`.

Name each `@Test` as a `given … when … then …` sentence using a backtick raw identifier, mirroring
the body markers. `given` is optional when there is no precondition.

```swift
@Test func `given a rename when parsing numstat then old and new are not swapped`() { … }
@Test func `when the hunk header omits counts then both default to one`() { … }
```

Group with `// MARK:`.

## Scenario fixture

Each test type uses a `private struct Scenario` that builds the subject from fakes, declared at the
**bottom** of the type, after the tests. Each test makes a fresh one in its body; there is no global
setup.

Constructor parameters are higher-level model values — a list of worktrees, an error to throw —
never fake instances. Expose a fake as a `let` only when a test inspects it; otherwise build it
inline in the subject's init. Do not hoist test data to type or `static` level: each test owns its
data in its `// given`.

## Handwritten fakes, never a mocking framework

There is no mocking framework and we are not adding one. Every double is a `FakeXxx` named after the
protocol it implements — never `Stub-`, `Mock-`, `No-` or `Empty-` — configurable through its
initialiser, with invocation tracking added only when a test asserts on it.

One configurable fake per collaborator, not a family of variants. A fake lives in its own file, never
inline in a test file.

## Assert on distinct, meaningful values

Use values that fail loudly if the wrong thing flows through, not defaults or placeholders. A
rename test whose old and new paths are both `file.txt` asserts nothing about the field order that
the spec warns is inverted between two git commands.

**Never call a production mapper inside an assertion.** Compare against a pre-built expected value,
so the test catches mapper bugs instead of mirroring them.

## The golden diff corpus

`Packages/Granita/Core/Diff/DomainTests/Fixtures/` holds unified diffs generated from the real `git`
binary by `Scripts/make-fixture-repo.sh`, committed so the parser suite runs on a machine with no
git. Every case the spec's §6 lists has a file: renames, conflicts, unborn HEAD, submodules, binary
patches and the `GIT binary patch` payload, CRLF, no-newline markers on each side, omitted hunk
counts, section headings, paths with spaces and non-ASCII, and an empty diff.

- **Assert against a named per-case fixture**, not against an offset into `working-tree.diff`. The
  case a test covers should be readable from the file it opens.
- **`case-empty.diff` is zero bytes on purpose.** A clean path must parse to zero files, not to one
  file with no hunks.
- **`worktree-list.z` has its root rewritten** to `/GRANITA_FIXTURE_ROOT`, because that command's
  output is inherently absolute. Substitute your own root back in rather than asserting on the
  token.
- **Do not hand-edit a fixture.** Change the generator and re-run `make fixtures`; the fixtures are
  what git produced, and editing one turns the corpus into a record of what we expected rather than
  what git does.
- The `.z` files are NUL-separated. Read them as bytes and split on NUL — decoding them as lines
  will silently merge records.

Tests that need a real repository — the git layer, worktree enumeration — drive the repositories
under `.fixtures/`, which `make fixtures` builds and `.gitignore` excludes. A fresh checkout has
none of them, so the failure says to run it rather than reading as a broken test. One of them,
`hostile`, exists only to defeat the invocation hardening; see the `git-invocation` skill before
asserting anything against it.

## Snapshot tests

`swift-snapshot-testing` is the **fourth** dependency, approved as **test-only**. It is attached to
the `GranitaMobileSnapshotTests` Xcode target and to nothing else — never to `Package.swift` — so the two
shipped apps stay on three.

- **They must be app-hosted.** A SwiftPM test target is hostless: there is no key window, so a
  SwiftUI view lays out against nothing and renders blank. `drawHierarchyInKeyWindow: true` needs a
  real host, which is why the target sets `TEST_HOST`.
- **The suite must be `@MainActor`.** Swift Testing runs `@Test` functions off the main actor, and
  rendering touches UIKit view properties, which trap. The trap is worse than a failure: the crash
  restarts the test host and the retry reports **"0 tests passed"**, so the suite goes green having
  rendered nothing.
- **Assert what ships.** Wrap the view the way the composition root wraps it. `.navigationTitle`
  renders nothing outside a navigation container, so an unwrapped baseline silently stops covering
  the title bar.
- **One parameterised test, not twenty functions.** `@Test(arguments: Case.all, SnapshotLayout.all)`
  produces every state × layout from one function, so adding a state is one line.

### Calibrating the tolerances — and proving they bite

`perceptualPrecision` is the **per-pixel colour** threshold and stays loose (0.87) to absorb runner
drift. `precision` is the **area** budget and must be **tight (0.999)**.

Aura's 0.98 was inherited and is wrong here. It allows 2% of pixels to move, and on a mostly-empty
screen a whole changed sentence is ~1.6% — the suite stayed green after "Local network access is
off" became "…is disabled". Aura's screens are dense; a budget calibrated for them hides real
changes on sparse ones.

**Prove a new suite can fail before trusting it.** Change a string the baseline captures, confirm
red, revert, confirm green. A snapshot test that cannot fail is a decoration, and it looks exactly
like one that works.

### Recording and reading failures

```bash
make snapshots         # render and compare against the committed baselines
make record-snapshots  # re-record all of them after a deliberate design change
```

- **The phone's baselines are recorded locally; the Mac's are recorded on the CI runner.** For the
  phone, `make record-snapshots` deletes the baselines and runs the suite **twice**: the first pass
  writes each missing baseline and fails that same run, so only the second pass tells you what was
  written renders stably. **Never record the phone's on CI** — that turns the test into a recorder of
  whatever the code does.
- **For the Mac, that rule is inverted, and `make snapshots-mac` is expected to be red on your
  machine.** A headless runner's window renders at 1× and a Retina laptop's at 2×, and the same code
  draws measurably different pictures: the drift is 0.737% of pixels against 0.162% for a real
  one-word change, and no tolerance separates them. Push, let `Snapshot tests (macOS)` fail, then
  `gh run download <id> -n snapshot-diffs-mac -D <dir>` and `Scripts/adopt-mac-baselines.py <dir>`.
  **Do not re-record the Mac's locally to make it green** — that is what turns every pull request
  red. `make record-snapshots` cannot reach them for that reason. See `decisions.md`.
- **A re-record is a design change, and needs the design to have changed first.** If baselines move
  and `.claude/docs/design.md` did not, the screen has drifted from the document; fix the screen, not
  the baseline. See the `design` skill.
- **Review every changed PNG by eye before committing.** Re-recording is the one operation in this
  repository that can make a wrong screen permanently correct.
- Baselines live in `__Snapshots__/<source file name>/`. The directory is named after the **source
  file**, not the test type, so renaming a test file orphans its baselines.
- Mismatches are written to `__SnapshotFailures__/` (gitignored) and CI turns them into one
  self-contained HTML page, uploaded as `snapshot-diffs`. Read the diff; do not guess.
- Reference PNGs are **16-bit Display P3**. `sips` and other 8-bit tooling truncate them silently and
  will report two different images as identical.

## Test kinds, and what the coverage report measures

A test declares its kind by **which directory it lives in**, because a directory is already a
bundle here and a bundle is the finest thing a coverage profile can be scoped to. Three kinds:

| Kind | Where | What it is |
|---|---|---|
| Unit | `Packages/Granita/<Unit>/<Feature>/<Layer>Tests/` | In-process, on the host, no simulator. The default — everything that is not one of the two below |
| Ui | `Apps/GranitaMobileUiTests/` | Behavioural: a screen rendered and driven, asserting what changed. **None exist yet** |
| Snapshot | `Apps/GranitaMobileSnapshotTests/` and `Apps/GranitaMacSnapshotTests/` | Rendered against a committed baseline — the phone on a simulator, the Mac on the machine itself |

**The Snapshot kind is two bundles and one row.** There is no macOS simulator, so the two render in
different places, but the question the row answers is the same for both and a platform axis is not
one a reader of the report cares about. The two profiles are merged before the row is taken.

The `Coverage` job runs the suite **once per kind**, plus once with the profiles merged, because
coverage is a property of the tests that ran: the only way to say what the snapshot tests reach, as
opposed to what everything reaches, is to run them alone and read the profile. The report is a row
per kind and nothing else — there is no per-module breakdown, because the question worth asking is
which kind of test reaches the code, not which directory it sits in.

Rules that follow:

- **A row of dashes is not a zero.** `Ui` reads `—` because the target does not exist yet. The first
  behavioural test brings `Apps/GranitaMobileUiTests` and its `project.yml` target with it, and the
  row starts carrying numbers on the next `main` run.
- **Read the Snapshot row as "was this rendered", not "was this asserted".** Rendering a screen
  executes every line that composes it, so `ClientConnectionUi` scores high the moment any baseline
  puts it on screen. Line coverage cannot tell a rendered line from a driven one. What the split is
  good for is the comparison *between* kinds on one module.
- **Do not "fix" a number by moving snapshot tests into the package.** A SwiftPM test target is
  hostless and renders blank; the split is the reason the numbers mean anything.
- **The Unit and All rows are measured over what a host test can reach** — the package, minus view
  bodies **wherever they live**, minus the composition roots, minus the handful of files named in
  `UNREACHABLE_FILES`. A SwiftUI body needs a renderer and a SwiftPM test target is hostless; no test
  constructs a composition root; and a test binary is unsigned, so it has no keychain for the identity
  store to write to. "Wherever they live" is load-bearing: `Presentation` holds both models and the
  screens composed from `Ui`, and only the models are reachable — a file named `…Screen` is a body
  and is excluded, while `ServerMacModel` is an ordinary object a test constructs and stays judged.
- **The Snapshot row excludes `Server/Api/Presentation`**, which is a presentation layer in the wire
  sense — routes and mapping — with no `Ui` sibling because it has no views. Counting it asks how
  much of the HTTP router a rendered screen executes.
- **The bar for `UNREACHABLE_FILES` is "unrunnable by construction", never "hard to test".** Adding
  a name there is a redefinition, so it comes with a rename of the scope string — that is what
  leaves the row unjudged for one run instead of failing the pull request that makes the change.
- **The Snapshot row is measured over the view layers alone.** A rendered view executes no
  repository and no parser, so every line of those the phone app happens to link is one a snapshot
  can never cover. Measured over the whole package the row fell whenever domain code was added
  anywhere under the app — a fact about the dependency graph, not about the snapshots. Scoped, it
  answers what it is for: of the code that draws screens, how much does a baseline put on screen.
  The Ui kind is **not** scoped, because a behavioural test drives the real app and reaching a
  repository is exactly what it does.
- **The rows have different denominators, so do not subtract them.** A pass only measures the code
  its own binaries map: the simulator never links the server modules, and the host cannot render a
  view. Each row answers "of what this kind could reach, how much did it", and only `All tests`
  spans the project. The corollary is a hazard worth knowing: deleting the last test that pulls a
  module into a binary removes that module's uncovered lines from the denominator, so the
  percentage goes *up*. Coverage rising after tests are deleted is the signature.
- **Lines and regions, not lines and branches.** swiftc emits no branch coverage — llvm-cov reports
  `branches: 0/0` for every Swift object, dependencies included, and no flag changes it. A region is
  an `if`, a `guard`, a `case`, a ternary or a closure body, and it moves when a path stops being
  taken even though the line total holds.
- **Every value is gated**, line and region, for every kind that both this run and the last `main`
  run put a number on. Plain ratchet, no floor, no slack. A kind measured for the first time is not
  judged — it joins on the next `main` run.
- **Changing what a row measures un-judges it for one run.** The summary records the files each
  kind's percentage was taken over, and the gate compares two numbers only when both were taken the
  same way: a redefinition would otherwise fail the pull request that makes it, for the
  redefinition rather than for a regression. Redefine deliberately, and expect one run with that
  row unenforced.
