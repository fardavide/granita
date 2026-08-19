---
name: git-invocation
description: How Granita invokes the git binary — the per-subcommand argument vector, the environment, draining and timeouts, and the six verified behaviours a naive implementation gets wrong.
when_to_use: >
  Consult before writing or changing any code that runs `git`, before adding a new subcommand to
  the git client, and when a git-layer test fails in a way that looks like git "behaving oddly".
  Also when parsing any -z output.
---

# Invoking git

Everything below was verified by running it, against git 2.52.0 locally and 2.55.0 on the CI runner.
`Scripts/make-fixture-repo.sh` asserts each behaviour on every CI run, so if one stops holding the
build goes red rather than the parser quietly reading the wrong field. Numbers and raw output are in
[`../../docs/verification.md`](../../docs/verification.md).

The spec's §5 is the authority; this is the operational summary.

## Build the argument vector per subcommand family

**Global prefix, every invocation.** Davide has external diff tools and pagers configured globally,
and every invocation must be hardened against them:

```
git -c core.pager=cat -c color.ui=false -c core.quotePath=false --no-pager <subcommand> …
```

**Diff-family suffix, appended only for `diff`, `show`, `log`, `diff-index`, `diff-tree`:**

```
--no-ext-diff --no-color
```

**These are not universal flags, and one of them fails silently.** Verified:

```
git status --porcelain=v2 --no-ext-diff       → error: unknown option `no-ext-diff'
git worktree list --porcelain --no-ext-diff   → error: unknown option `no-ext-diff'
git rev-parse --no-color --show-toplevel      → prints "--no-color" as an output line, exit 0
```

The `rev-parse` case is the dangerous one: it does not fail, it emits an extra line, so parsing the
first line of `--show-toplevel` yields `--no-color` as the repository root.

**Test the argument array, not the outcome.** A unit test asserts the exact vector each command
family produces. "The command succeeded" is not evidence: the `rev-parse` case succeeds.

## Environment, every child process

- `GIT_OPTIONAL_LOCKS=0` — read operations never take the index lock and never fight a running Claude
  Code session. The cost is that `git status` cannot write back a refreshed index, so each refresh
  re-stats the worktree; that is why status is rate-limited per worktree.
- `GIT_TERMINAL_PROMPT=0`.
- Clear inherited `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`.
- Always an argument array, never a shell. Always `--` before paths.
- Resolve the binary once at startup: `/usr/bin/git`, then `xcrun -f git`, then `PATH`. Surface a
  clear error in the Mac UI if there is none.

## Process I/O and timeouts

- **Drain stdout and stderr concurrently, then await exit.** A macOS pipe buffer is 64 KiB and the
  size guard permits a 2 MB diff, so awaiting termination before draining — or draining stdout to
  completion before touching stderr — hangs hard on exactly the large diffs the guards exist for.
- **Enforce the output cap by cancelling the drain**, not by letting the buffer fill.
- **Never `killpg`.** The standard process API gives the child our own process group, so killing the
  group signals the menu bar app itself. On a 10 s timeout: `terminate()`, wait 500 ms, then
  `SIGKILL` the pid.

This is the whole reason swift-subprocess is a dependency rather than a convenience.

## One comparison is the source of truth

The tracked change set **and** its stats come from one comparison with identical options.

Taking the file list from `status` and the stats from `diff --numstat` runs rename detection twice
over different comparisons — status compares HEAD→index and index→worktree, diff compares
HEAD→worktree — and they disagree routinely. A file staged as a delete plus an unstaged add is one
rename to `diff HEAD` and two entries to `status`, which produces files with no stats, stats with no
file, and totals that do not add up.

`status --porcelain=v2 -z` is used for the worktree revision and for conflicts, and for nothing else.

## Exit codes

For the diff family, **0 and 1 are both success**; 2 and above are errors. `git diff --no-index`
exits 1 when files differ, which is the normal case for an untracked file rendered as a full
addition.

## Parse bytes, and mind the two rename layouts

Use `-z` wherever git offers it and split on NUL. Paths on disk are bytes and not necessarily valid
UTF-8: decode lossily for display, keep the raw bytes for re-invocation.

The two commands that report renames put the paths in **opposite orders**:

```
diff HEAD -z -M --numstat    <added>TAB<deleted>TAB NUL <oldPath> NUL <newPath> NUL
                             ^ an extra EMPTY field marks the rename form
                             <added>TAB<deleted>TAB<path> NUL          ← non-rename form

status --porcelain=v2 -z     2 RM N… R100 <newPath> NUL <oldPath> NUL
                                          ^ NEW first
```

The empty field in `--numstat -z` is by design, so a reader can tell the two record shapes apart
without looking ahead. A naive NUL splitter desynchronises for the rest of the stream at the first
rename, and copying the porcelain-v2 field order into the numstat parser swaps old and new on every
one. `diff HEAD -z -M --raw` follows the **numstat** order, old then new.

## Unmerged records carry ten fields

`status --porcelain=v2` unmerged records start with `u` and have **10** fields, not the 8 of `1` and
`2` records:

```
u UU N… 100644 100644 100644 100644 <h1> <h2> <h3> f.txt
```

A field-count parser written for the ordinary records consumes into the next one. Claude Code runs
rebases and merges, so this will happen.

Verified, and it simplifies the parser: `git diff HEAD` on a conflicted path emits a **normal**
unified diff carrying `<<<<<<<`, `=======`, `>>>>>>>` inline — **not** a combined `diff --cc`. No
combined-diff support is needed; those lines are tagged as conflict markers and the client renders
them distinctly.

## Unborn HEAD

In a repository with no commits, `git diff HEAD` exits 128 with `fatal: ambiguous argument 'HEAD'`
while `git status` works fine. It happens with a fresh project and with `git worktree add --orphan`.

Resolve `git rev-parse --verify --quiet HEAD` once per worktree refresh. If it fails, flag the
worktree and substitute the empty tree object `4b825dc642cb6eb9a060e54bf8d69288fbee4904` everywhere
`HEAD` would appear as a revision.

## Hashing

Never read and hash file bytes yourself — a 1,000-file worktree refreshing every 400 ms would be real
I/O. The worktree blob object id comes from a single batched `git hash-object --stdin-paths` over the
changed paths; for a deleted file it is the all-zero id.
