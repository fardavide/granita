# The golden diff corpus, fixture by fixture

Per-fixture facts behind the rules in the `swift-testing` skill's "The golden diff corpus" section.

## What is in the corpus

`Packages/Granita/Core/Diff/DomainTests/Fixtures/` holds unified diffs generated from the real `git`
binary by `Scripts/make-fixture-repo.sh`, committed so the parser suite runs on a machine with no
git.

Every case the spec's §6 lists has a file:

- renames
- conflicts
- unborn HEAD
- submodules
- binary patches, and the `GIT binary patch` payload
- CRLF
- no-newline markers on each side
- omitted hunk counts
- section headings
- paths with spaces and non-ASCII
- an empty diff

## Individual fixtures worth knowing

- **`case-empty.diff` is zero bytes on purpose.** A clean path must parse to zero files, not to one
  file with no hunks.
- **`worktree-list.z` has its root rewritten** to `/GRANITA_FIXTURE_ROOT`, because that command's
  output is inherently absolute. Substitute your own root back in rather than asserting on the
  token.

## The generated repositories under `.fixtures/`

Tests that need a real repository — the git layer, worktree enumeration — drive the repositories
under `.fixtures/`, which `make fixtures` builds and `.gitignore` excludes.

A fresh checkout has none of them, so the failure says to run it rather than reading as a broken
test.

One of them, **`hostile`**, exists only to defeat the invocation hardening; see the `git-invocation`
skill before asserting anything against it.
