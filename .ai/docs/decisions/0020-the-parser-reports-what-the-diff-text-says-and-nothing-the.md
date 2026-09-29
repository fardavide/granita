# The parser reports what the diff text says, and nothing the git layer already knows

A parsed file carries its path, the path it came from when that differs, whether git refused to diff
it, whether it is a gitlink, and its hunks. It deliberately does **not** carry a status or a line
count, even though both are readable from the text: §5.3's rule is that the change set and its stats
come from one comparison with identical options, and a status re-derived here would be exactly the
second, disagreeing source that rule exists to prevent. A staged delete plus an unstaged add is one
rename to the comparison the stats come from — and the per-file diff would have to agree with it by
construction rather than by coincidence.

Binary and gitlink are the exceptions because only the diff text states them: a one-line summary or a
`GIT binary patch` payload instead of hunks, and mode 160000 on the index line.

