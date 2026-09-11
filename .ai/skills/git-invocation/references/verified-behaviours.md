# The git behaviours this layer is built on

Everything here was verified by running it, against **git 2.52.0 locally and 2.55.0 on the CI
runner**. `Scripts/make-fixture-repo.sh` asserts each behaviour on every CI run, so if one stops
holding the build goes red rather than the parser quietly reading the wrong field.

Numbers and raw output are in [`../../docs/verification.md`](../../docs/verification.md). The spec's
§5 is the authority; the skill beside this file is the operational summary.

## Contents

- Why the flags are pinned rather than taken from configuration
- Why `status --porcelain=v2 -z` is pinned in full
- The flags that are not universal, and the one that fails silently
- Why `.fixtures/hostile` exists
- Why one comparison must be the source of truth
- Why the drain must be concurrent, and why never `killpg`
- Why `GIT_OPTIONAL_LOCKS=0` costs something
- The two rename layouts, and why the empty field is there
- Why unmerged records carry ten fields
- Unborn HEAD, exit codes, and batched hashing

## Why the flags are pinned rather than taken from configuration

Davide has external diff tools and pagers configured globally, so every invocation must be hardened
against them.

**The two diff prefixes are pinned because the parser strips a leading `a/` and `b/`, and both
strings are configurable:**

- `diff.noprefix`, which is set in Davide's own configuration, removes them
- `diff.mnemonicPrefix` spells them `i/`, `w/` and `c/`

Neither fails. Both produce paths the parser silently mis-reads.

**Diff-family flags go immediately after the subcommand, not at the end**, because everything past
`--` is a pathspec — a flag appended to a vector ending in a path is read as the name of another
file to diff.

## Why `status --porcelain=v2 -z` is pinned in full

Its bytes are the worktree's revision.

`status.showUntrackedFiles=no` empties the section entirely. And with the collapsed default, a
*second* file appearing inside an already-untracked directory leaves the output **byte for byte
identical**, so the revision does not move and the phone never refreshes.

## The flags that are not universal, and the one that fails silently

```
git status --porcelain=v2 --no-ext-diff       → error: unknown option `no-ext-diff'
git worktree list --porcelain --no-ext-diff   → error: unknown option `no-ext-diff'
git rev-parse --no-color --show-toplevel      → prints "--no-color" as an output line, exit 0
```

**The `rev-parse` case is the dangerous one**: it does not fail, it emits an extra line, so parsing
the first line of `--show-toplevel` yields `--no-color` as the repository root.

This is why a unit test asserts the exact argument vector rather than the outcome — "the command
succeeded" is not evidence, because the `rev-parse` case succeeds.

## Why `.fixtures/hostile` exists

Every other fixture is built with `GIT_CONFIG_GLOBAL=/dev/null`, so none of them can tell a hardened
invocation from an unhardened one — **the hardening flags could all be deleted and the suite would
stay green.**

`.fixtures/hostile` carries that configuration in its own config, where a child reads it whatever
the environment says.

When you add a flag to the vector, add the config key that defeats it there, and check the new test
goes red when the flag is removed.

## Why one comparison must be the source of truth

Taking the file list from `status` and the stats from `diff --numstat` runs rename detection twice
over different comparisons — status compares HEAD→index and index→worktree, diff compares
HEAD→worktree — and they disagree routinely.

A file staged as a delete plus an unstaged add is **one rename to `diff HEAD` and two entries to
`status`**, which produces files with no stats, stats with no file, and totals that do not add up.

## Why the drain must be concurrent

A macOS pipe buffer is **64 KiB** and the size guard permits a **2 MB** diff, so awaiting
termination before draining — or draining stdout to completion before touching stderr — hangs hard
on exactly the large diffs the guards exist for.

This is the whole reason swift-subprocess is a dependency rather than a convenience.

## Why never `killpg`

The standard process API gives the child our own process group, so killing the group signals the
menu bar app itself.

## Why `GIT_OPTIONAL_LOCKS=0` costs something

Read operations never take the index lock and never fight a running Claude Code session. The cost is
that `git status` cannot write back a refreshed index, so each refresh re-stats the worktree — which
is why status is rate-limited per worktree.

## The two rename layouts, and why the empty field is there

```
diff HEAD -z -M --numstat    <added>TAB<deleted>TAB NUL <oldPath> NUL <newPath> NUL
                             ^ an extra EMPTY field marks the rename form
                             <added>TAB<deleted>TAB<path> NUL          ← non-rename form

status --porcelain=v2 -z     2 RM N… R100 <newPath> NUL <oldPath> NUL
                                          ^ NEW first
```

The empty field in `--numstat -z` is **by design**, so a reader can tell the two record shapes apart
without looking ahead.

A naive NUL splitter desynchronises for the rest of the stream at the first rename, and copying the
porcelain-v2 field order into the numstat parser swaps old and new on every one.

`diff HEAD -z -M --raw` follows the **numstat** order, old then new.

## Why unmerged records carry ten fields

`status --porcelain=v2` unmerged records start with `u` and have **10** fields, not the 8 of `1` and
`2` records:

```
u UU N… 100644 100644 100644 100644 <h1> <h2> <h3> f.txt
```

A field-count parser written for the ordinary records consumes into the next one. Claude Code runs
rebases and merges, so this will happen.

**Verified, and it simplifies the parser:** `git diff HEAD` on a conflicted path emits a **normal**
unified diff carrying `<<<<<<<`, `=======`, `>>>>>>>` inline — **not** a combined `diff --cc`. No
combined-diff support is needed; those lines are tagged as conflict markers and the client renders
them distinctly.

## Unborn HEAD

In a repository with no commits, `git diff HEAD` exits **128** with
`fatal: ambiguous argument 'HEAD'` while `git status` works fine. It happens with a fresh project
and with `git worktree add --orphan`.

## Why the diff family treats exit 1 as success

`git diff --no-index` exits 1 when files differ, which is the normal case for an untracked file
rendered as a full addition.

## Why hashing is batched

A 1,000-file worktree refreshing every 400 ms would be real I/O if the layer read and hashed file
bytes itself.
