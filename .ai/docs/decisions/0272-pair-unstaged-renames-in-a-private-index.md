# Pair unstaged renames in a private index

A filesystem move can leave a tracked deletion and an untracked destination. Git's usual
HEAD-to-worktree diff cannot pair them because it only sees the deletion. [0002](0002-uncommitted-working-state-only-no-committed-history.md)
still defines what the reader can see. For the case that Git recognizes as a rename, the
untracked destination instead appears with its source and the edits between them.

Keep the tracked comparison and use its unmatched deletions alongside non-ignored untracked
paths as candidates. A private index containing only the destinations lets Git compare their
working files against HEAD. The index entries use the empty blob identifier and have no
cached file stat data. Git reads the working tree to get their contents, and the real index
and object store stay untouched. Both paths reach Git as literal pathspecs. The private
index is discarded after each comparison.

The rename-only comparison supplies both paths and line counts together. Opening the file
uses the same comparison with both paths and returns just the edited hunks. The candidate
count is bounded by the worktree's changed-file limit. If the candidate comparison fails
or exceeds the output limit, the original entries remain visible.
