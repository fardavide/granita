# A path git will not hash costs its own content hash and nothing else

**Found by running the product, on a real iPhone, against real repositories.** The worktree list
failed and *Try Again* looked dead; the Mac's log said `hashWorktreeFiles(...) failed` over and over.
The cause is a **symlink pointing at a directory**: `git ls-files --others` reports it as an ordinary
untracked path — git treats a symlink as a file, so there is no trailing separator to filter on — and
`git hash-object --stdin-paths` follows it, finds a directory, and exits 128 for the **whole batch**.
Two of Davide's `bandlab-android` worktrees carry one, so `/v1/worktrees` could not answer at all.

`WorktreeService`'s own comment predicted the shape and filtered the two cases it knew — a deleted
file and a submodule. What it could not filter is a path that looks ordinary and is not, and the
general answer is not a longer filter: tomorrow it is a fifo, a socket, or a file the server cannot
read.

So the batch is still tried first and is still one process for a whole worktree. **Only when it fails**
does the service hash the paths one at a time, which costs a process per file exactly once, in a
worktree that has something wrong with it. Every file git *can* hash keeps a real content hash, which
is what makes a viewed mark self-correcting when the file changes underneath it.

> Rejected: giving the whole batch the absent id on failure. It is two lines shorter and it makes
> "viewed" stick to content nobody has seen, for every file in that worktree — a silent weakening of
> the one thing this product is for.
>
> Rejected: locating the bad path from the partial output of the failed batch. Measured first, and
> git does emit the hashes it managed before dying, so the count would name the culprit exactly —
> but `GitError.commandFailed` carries git's standard error and **not** its standard output, so
> those hashes never reach the caller. Widening the error to carry stdout would put a private
> repository's contents into an error value that gets logged, which is the boundary the git
> decorator already exists to hold.

