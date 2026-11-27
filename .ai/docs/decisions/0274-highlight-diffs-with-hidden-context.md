# Highlight diffs with hidden context

Joining visible hunks can open a documentation comment in one hunk and omit its closing delimiter
in the gap. The lexer then treats subsequent code as part of the comment. The Kotlin regression
covers the closing delimiter on both sides and retains the original hunk boundaries.

The diff response includes bounded source when the visible hunks omit lines. The server reuses the
working copy it already reads to count lines and reverses the patch to recover the original source.
It requires matching Git blob IDs across both reads and checks the new hunk contents against that
working copy. Added and deleted files already contain their own source in the diff.

The reader checks the returned source against its visible rows, expands tabs, and highlights each
side from line one. The reader retains highlights only for rows it currently presents, indexed by
file line number. Context expansion revalidates newly visible rows. Each side's existing line and
byte limits also bound the extra payload. Older servers and diffs that exceed those bounds can
still use the visible lines for highlighting.
