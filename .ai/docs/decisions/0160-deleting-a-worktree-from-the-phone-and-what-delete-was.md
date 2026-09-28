# Deleting a worktree from the phone, and what "delete" was allowed to mean

`SPEC.md` §11 lists **pruning worktrees** in the v2 backlog, and design §2 leans on that in as many
words when it decides the locked flag earns no pixels: *"v1 cannot prune worktrees, which is the only
operation it would block."* Davide asked for it on 28 August 2026 anyway, with a confirmation in
front of it. So this is a deliberate departure from the spec's own scope line rather than an
oversight, and it is the first thing in this product that writes to a repository — everything before
it wrote to this Mac's own JSON document.

**It is `worktree remove --force`, once.** The unforced form refuses whenever there is anything
uncommitted, which is *every worktree this app lists*: the sidebar hides the quiet ones by default
and the whole product exists to show uncommitted work. An unforced deletion would therefore be a
control that refuses on nearly every row it is offered on, which is worse than not having one. The
confirmation is not ceremony around a safe operation; it is the entire safeguard, which is why the
dialog is the one place the cost is stated and why the subject it is handed carries the row's stats
rather than only its name.

**A second `--force` was available and was not sent** — see the entry below, which reverses that on
5 September 2026 after it turned out to refuse the deletion on nearly every row. The reasoning as it
stood: `-f -f` overrides a lock, and a lock is a person at that Mac saying do not remove this. A lock
a phone can wave through is not a lock, so a locked worktree is refused. That is what put `isLocked`
to work for the first time — the flag design §2 filed as plumbing, on the grounds that the only
operation it blocked did not exist.

**The branch survives.** What an agent leaves behind is a directory and some uncommitted work; the
branch is cheap, is not in the way, and `git branch -D` would take unmerged commits with it — a much
larger promise than the one a confirmation naming a worktree can honestly make.

**Two refusals are predicted rather than discovered.** The primary checkout and a locked worktree are
both visible in what the registry already holds, so the route refuses them itself instead of running
git and forwarding `fatal: '…' is a main working tree`. That buys a code the phone branches on —
`worktreeNotDeletable`, new to the contract and therefore a contract change — rather than a git
sentence it can only print, and it keeps an absolute path on this Mac out of an answer to a client
that is never otherwise given one. Git refuses both regardless, so this is a better sentence rather
than the only guard. Where both are true the row says *primary*, because that is a fact about the
repository rather than a setting somebody can undo, and the alternative sends a reader off to unlock
something that would still refuse afterwards.

**The row decides deletability, and it carries a reason rather than a boolean.** A control that is
absent and a control that is disabled and says why are different answers to *why can I not do this
here*, and only the design chooses between them — but a boolean has already thrown away the half
that lets a screen give either. So `WorktreeListRow` carries three cases, and a screen physically
cannot offer the control on a worktree that would refuse.

**The row is dropped only once the Mac says it is gone.** Renaming and pinning both write
optimistically here; deleting must not. A rename that silently failed shows the wrong name until the
next read, which a reader notices and can repeat. A deletion that silently failed shows a worktree
that still exists as destroyed, which nobody goes looking for. A `worktreeGone` refusal is the one
exception and counts as success: an agent removes a worktree every day, so a reader can confirm one
that stopped existing between the read and the tap, and the difference is only *who* removed it.

**The route runs git from the project rather than from inside the worktree.** Git accepts being asked
from inside the directory it is about to delete — measured on 2.52.0, it works and exits 0 — and
there is no reason to ask that of a process.

### What was verified by running it, on git 2.52.0

Every rule above rests on one of these rather than on documentation:

| Asked | Answer |
|---|---|
| `worktree remove` on a dirty worktree | exit 128, `contains modified or untracked files, use --force to delete it` |
| `worktree remove --force`, run from inside that worktree | exit 0, silent, directory gone, **branch still there** |
| `worktree remove --force` on a locked worktree | exit 128, `cannot remove a locked working tree; use 'remove -f -f' to override or unlock first` |
| `worktree remove --force` on the main worktree | exit 128, `'…' is a main working tree` |
| `worktree remove --no-ext-diff …` | exit 129, `error: unknown option` — it is not a diff-family command |
| `worktree remove --force --` before the path | accepted, so the always-`--`-before-paths rule holds here too |
| `worktree remove --force` on a worktree whose directory somebody already deleted | exit 0 — git cleans up the admin files |
| the same command a second time | exit 128, `'…' is not a working tree`, which the registry refuses before git is reached |

### The tests own a repository rather than borrowing the fixtures

A removal test driven against the committed fixtures takes a checkout out from under everything else
that reads them, and the suite asserting the main fixture has three worktrees is where it would
surface — a run later, in a test that changed nothing. `make fixtures` puts it back, which means the
second run of an unchanged tree behaves differently from the first, and that is worse than a slow
test. So `DisposableRepository` builds one per test and deletes it afterwards.

**Its paths are read back from `git worktree list` rather than computed**, and that cost two red
runs before it was read rather than guessed. An identifier is a hash of the path *string*, and two
plausible spellings of one directory hash differently: a `URL` built for a directory carries a
trailing separator git never emits, and `resolvingSymlinksInPath()` leaves `/var/folders` alone on
macOS where git reports `/private/var/folders`. Either one produces an identifier matching nothing in
the registry, and every route then answers `worktreeGone` about a worktree sitting right there.

---

