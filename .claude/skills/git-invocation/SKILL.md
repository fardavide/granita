---
name: git-invocation
description: How Granita invokes the git binary — the per-subcommand argument vector, the hardening flags, the environment, concurrent draining and timeouts, -z parsing including the two opposite rename layouts, and the six verified behaviours a naive implementation gets wrong.
when_to_use: >
  Consult before writing or changing any code that runs `git`, before adding a new subcommand to
  the git client, and when a git-layer test fails in a way that looks like git "behaving oddly".
  Also when parsing any -z output.
---

# Invoking git

The spec's §5 is the authority; this is the operational summary. Every rule below was verified by
running it — the raw output, the version numbers and the reason each rule exists are in
[verified-behaviours.md](references/verified-behaviours.md). Read it before deleting a flag that
looks redundant; several of them are, until they are not.

## Build the argument vector per subcommand family

**Global prefix, every invocation:**

```
git -c core.pager=cat -c color.ui=false -c core.quotePath=false --no-pager <subcommand> …
```

**Diff-family flags, only for `diff`, `show`, `log`, `diff-index`, `diff-tree`, and placed
immediately after the subcommand rather than at the end:**

```
--no-ext-diff --no-color --src-prefix=a/ --dst-prefix=b/
```

Immediately after, because everything past `--` is a pathspec.

**`status --porcelain=v2 -z` is pinned in full**, because its bytes are the worktree's revision:

```
--renames --untracked-files=all --no-branch --no-show-stash
```

- **These are not universal flags, and one of them fails silently.** `--no-ext-diff` errors on
  `status` and `worktree list`; `--no-color` on `rev-parse` is echoed as an output line with exit 0,
  so `--show-toplevel` yields `--no-color` as the repository root.
- **Test the argument array, not the outcome.** A unit test asserts the exact vector each command
  family produces. "The command succeeded" is not evidence.
- **Prove the hardening against a repository configured to defeat it.** When you add a flag here,
  add the config key that defeats it to `.fixtures/hostile`, and check the new test goes red when
  the flag is removed. No other fixture can tell a hardened invocation from an unhardened one.
- **An argument passed as bytes is NUL-terminated before it leaves for the child process.**
  swift-subprocess's byte-array `Arguments` hands each element to `strdup`, which reads past the end
  of a Swift array until it meets a zero byte, so an unterminated element arrives carrying whatever
  the allocator left beside it. The terminator belongs at that boundary — `ProcessGitClient` — and
  never in the vector, which stays assertable as text. **A corrupted pathspec is silent**: it matches
  nothing, so `git diff` prints nothing, says nothing on standard error and exits 0.

## Environment, every child process

- `GIT_OPTIONAL_LOCKS=0` — read operations never take the index lock and never fight a running
  Claude Code session. The cost is that status is rate-limited per worktree.
- `GIT_TERMINAL_PROMPT=0`.
- Clear inherited `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`.
- Always an argument array, never a shell. Always `--` before paths.
- Resolve the binary once at startup: `/usr/bin/git`, then `xcrun -f git`, then `PATH`. Surface a
  clear error in the Mac UI if there is none.

## Process I/O and timeouts

- **Drain stdout and stderr concurrently, then await exit.** Awaiting termination before draining —
  or draining stdout to completion before touching stderr — hangs hard on exactly the large diffs
  the size guards exist for.
- **Enforce the output cap by cancelling the drain**, not by letting the buffer fill.
- **Never `killpg`.** The child shares our process group, so killing the group signals the menu bar
  app itself. On a 10 s timeout: `terminate()`, wait 500 ms, then `SIGKILL` the pid.

## One comparison is the source of truth

The tracked change set **and** its stats come from one comparison with identical options. Mixing the
file list from `status` with the stats from `diff --numstat` runs rename detection twice over
different comparisons, and they disagree routinely.

`status --porcelain=v2 -z` is used for the worktree revision and for conflicts, and for nothing else.

## Exit codes

For the diff family, **0 and 1 are both success**; 2 and above are errors.

## Parse bytes, and mind the two rename layouts

Use `-z` wherever git offers it and split on NUL. Paths on disk are bytes and not necessarily valid
UTF-8: decode lossily for display, keep the raw bytes for re-invocation.

**The two commands that report renames put the paths in opposite orders:**

```
diff HEAD -z -M --numstat    …TAB…TAB NUL <oldPath> NUL <newPath> NUL   ← OLD first
status --porcelain=v2 -z     2 RM N… R100 <newPath> NUL <oldPath> NUL   ← NEW first
```

An **extra empty field** marks the rename form in `--numstat -z`. A naive NUL splitter desynchronises
for the rest of the stream at the first rename, and copying the porcelain-v2 field order into the
numstat parser swaps old and new on every one. `diff HEAD -z -M --raw` follows the **numstat** order.

**Unmerged `status --porcelain=v2` records start with `u` and carry 10 fields**, not the 8 of `1`
and `2` records. A field-count parser written for the ordinary records consumes into the next one,
and Claude Code runs rebases and merges, so this will happen.

**No combined-diff support is needed.** `git diff HEAD` on a conflicted path emits a normal unified
diff carrying `<<<<<<<`, `=======`, `>>>>>>>` inline, not a `diff --cc`.

## Unborn HEAD

In a repository with no commits, `git diff HEAD` exits 128 while `git status` works fine.

Resolve `git rev-parse --verify --quiet HEAD` once per worktree refresh. If it fails, flag the
worktree and substitute the empty tree object `4b825dc642cb6eb9a060e54bf8d69288fbee4904` everywhere
`HEAD` would appear as a revision.

## Hashing

Never read and hash file bytes yourself. The worktree blob object id comes from a single batched
`git hash-object --stdin-paths` over the changed paths; for a deleted file it is the all-zero id.
