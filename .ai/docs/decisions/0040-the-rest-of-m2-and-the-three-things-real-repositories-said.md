# The rest of M2, and the three things real repositories said that the spec did not

### `cwd` is not on every session record, and there is no `summary` record at all

SPEC §7 describes both. Read against the 117 real transcripts under `~/.claude/projects` on
2026-08-21: `cwd` appears on `user`, `assistant`, `attachment` and `system` records and on none of
the six other kinds — one of which is routinely the *first* line of a file, so a reader taking the
first record's `cwd` gets nothing. And across 400 files there are **zero** `summary` records against
4,468 `custom-title` and 10,023 `last-prompt`. `custom-title` is the analogue and is what a label
prefers now; `last-prompt` is deliberately unused, because the most recent instruction names what a
session got down to rather than what it is about.

§7's `projects/*/*.jsonl` turns out to be exactly right and worth defending: one level below the
sessions are 1,237 subagent transcripts sharing their session's `cwd`, whose opening turn is a brief
nobody typed.

### A session belongs to one worktree, so the matching is decided over all of them at once

Every worktree an agent creates lives *under* the checkout it branched from, so "is this session's
directory inside this worktree" answers yes for the outer one every single time. Asked per worktree,
the primary checkout takes the name of whatever was last done in any worktree beneath it. Each
session is therefore assigned to the closest worktree containing it, and only then does each
worktree pick its best session. Containment stops on a separator, or `/repo/slice` claims
`/repo/slice-two`.

### A nested worktree is an untracked *directory*, and hashing it fails the whole batch

`ls-files --others` does not descend into another repository: it reports the whole thing as one
entry with a trailing separator. Claude Code puts every worktree it makes under
`.claude/worktrees/`, so the primary checkout of any project an agent has touched has one — and it
is not a file. Left in, it is an added file nobody can open; worse, `hash-object --stdin-paths`
refuses it and **the whole batch fails**, which took the entire change set down with it. Found by
running the server against the fixture repository rather than by reading anything. A deleted file
and a submodule are excluded from the batch for the same reason.

### An unborn HEAD is forty zeroes, not an absent line

`worktree list --porcelain` reports it as `HEAD 0000…` on a line present like any other, so a reader
checking whether the line exists concludes that a repository with no commits has one.

### The change set carries a byte path the wire does not

`FileChange.path` is a lossy decoding for display; re-invoking git on it would address a file that
does not exist. The change set therefore carries a separate identifier-to-bytes map, off the wire,
and anything that goes back to git looks the path up there.

### No exit code, but the error is allowed to be concrete

Stated when the git client landed and it held: what a caller gets back is bytes and whether they are
all of them. The failure path is the exception — it carries git's standard error verbatim and the
exit code, because it is read on a phone by someone who cannot open a terminal.

### Auth is off under `--insecure-http`, and that is not a hole

A token over plaintext is a token everyone on the network already has, so demanding one would be
theatre. The flag exists so a TLS problem can never leave code unreviewable, it is off by default,
and it is never reachable from the Mac app's UI. TLS itself, the Keychain identity and SPKI pinning
are M3's, where SPEC §12 puts them.

### Timestamps are ISO 8601, and that is asserted rather than assumed

The date format on the wire is currently whatever the HTTP framework's encoder defaults to. A test
reads the raw JSON and checks it parses as ISO 8601, so a framework upgrade that switches to
seconds-since-epoch is a red test rather than a phone showing every worktree as modified in 1970.
Pinning the encoder explicitly is worth doing when M3 next touches this module.

