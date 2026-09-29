# What a folder scan will not look at, and why each refusal is there

SPEC §9 names six directories a scan skips — `node_modules`, `.build`, `DerivedData`, `Pods`,
`vendor`, `target` — and the §4 frames show `vendor/swift-nio` as a candidate. That is the second
place the design and the specification have disagreed, so it went to Davide rather than being
resolved by whoever read one of them last. **Answered on 23 August 2026: the specification wins.**
The drawing's row reads as an illustration of a candidate at a nested path, which the sheet needed an
example of; the skip list is explicit and argued. Recorded because `design-handoff` says a
disagreement is worth a line rather than a silent resolution.

Three more limits are ours, and none of them is in either document:

- **Hidden directories are refused wholesale** rather than named one at a time. Everything under a
  leading dot is a cache, a trash can or an agent's scratch space — including every worktree Claude
  Code creates, which lives under `.claude/worktrees` and is a checkout of a repository the reader
  already has. It also makes `.build`'s presence on the specification's list redundant, which is
  fine: the list is what SPEC says and is kept as written.
- **Four levels below the folder that was picked.** A scan is a person pointing at where they keep
  their work, not a search of a disk, and an unbounded walk of a home directory is minutes of I/O for
  repositories nobody filed there on purpose.
- **A candidate is a folder with a `.git` *directory* in it**, never a `.git` file. The difference is
  a linked worktree, whose `.git` is a file pointing back at the repository it belongs to — adding
  one as a project would enumerate exactly the worktrees that repository already offers, under a
  second name, with a second switch over the same files.

Symbolic links are not followed either, and that one is not a policy so much as a termination
argument: a link is somewhere else's directory reached by a second name, so following one offers the
same repository twice, and a link pointing back up the tree is a walk that does not end.

**The scan runs no git at all**, which is worth stating because everything else on this tab does.
Thirty candidates is thirty `.git` directories found by `FileManager` and zero subprocesses. What
makes that safe is that the one add which *can* be aimed anywhere — the folder picker — checks, and
the sheet's candidates are folders this Mac found a `.git` in a moment ago.

