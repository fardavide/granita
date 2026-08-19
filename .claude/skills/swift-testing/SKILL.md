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

## Screenshot tests

None yet, and no CI job for them, because there is no UI to render. They land with the first `Ui`
slice, in an app-hosted target, and `.github/rulesets/protect-main.json` gains the job name in the
same pull request. Adding the library is a fourth dependency and therefore a conversation with
Davide first.
