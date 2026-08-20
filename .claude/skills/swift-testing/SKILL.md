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
under `.fixtures/`, which `make fixtures` builds and `.gitignore` excludes.

## Snapshot tests

`swift-snapshot-testing` is the **fourth** dependency, approved as **test-only**. It is attached to
the `GranitaMobileTests` Xcode target and to nothing else — never to `Package.swift` — so the two
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

- Record **locally**: delete the baseline and run; the first pass writes it and fails, a re-run
  compares. **Never record on CI** — that turns the test into a recorder of whatever the code does.
- Baselines live in `__Snapshots__/<source file name>/`. The directory is named after the **source
  file**, not the test type, so renaming a test file orphans its baselines.
- Mismatches are written to `__SnapshotFailures__/` (gitignored) and CI turns them into one
  self-contained HTML page, uploaded as `snapshot-diffs`. Read the diff; do not guess.
- Reference PNGs are **16-bit Display P3**. `sips` and other 8-bit tooling truncate them silently and
  will report two different images as identical.

### They do not feed the coverage ratchet

The `Coverage` job measures `swift test` over the package, and snapshot tests live in the Xcode
target — so `ClientConnectionUi` reads 0% there despite being covered by 24 baselines. The two gates
are separate on purpose; do not "fix" the coverage number by moving snapshot tests into the package,
because a hostless target renders blank.
