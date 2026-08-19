// ServerWatchData — one FSEvents stream over the union of every visible project root, every
// worktree path, and every per-worktree gitdir. A recursive stream per project root does not
// cover a linked worktree, whose HEAD and index live under the main repository's gitdir.
//
// Milestone M6.
