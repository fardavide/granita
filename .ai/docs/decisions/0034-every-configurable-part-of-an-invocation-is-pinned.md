# Every configurable part of an invocation is pinned, including the ones that are already the default

§5.1 hardens the invocation against a developer's global configuration, and lists the pager, the
colour setting and the path-quoting rule. Two more were found by reading the configuration keys that
exist rather than the ones the spec names.

**The path prefixes.** M1 recorded this as a requirement the git layer inherits, and it is now
`--src-prefix=a/ --dst-prefix=b/` on every diff-family command. `diff.noprefix` is set in Davide's
own configuration and would take the first two characters off every path in the product;
`diff.mnemonicPrefix` would spell them `i/`, `w/` and `c/` instead. Neither fails.

**The status invocation, in full.** Its bytes are hashed into the worktree's revision, which is the
only thing that tells the phone something moved, so anything that changes those bytes changes when
the phone refreshes. `status.showUntrackedFiles=no` empties the section outright. The collapsed
default is subtler and was verified rather than assumed: with `--untracked-files=normal`, adding a
second file inside an already-untracked directory leaves the output **byte for byte identical**, so
the revision does not move and the phone never learns. `all` is therefore pinned, along with
`--renames`, `--no-branch` and `--no-show-stash`.

The diff-family flags go **immediately after the subcommand** rather than at the end, because
everything past `--` is a pathspec: a flag appended to a vector that ends in a path is read as the
name of another file to diff.

