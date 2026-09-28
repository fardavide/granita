# Directories above files, and the sort is over what the row reads

Git orders a diff by whole-path bytes, which interleaves the two — `Makefile` lands between `Apps/`
and `Sources/`. A project view does not, and "Android Studio style" is the brief, so directories sort
above files and each group sorts alphabetically.

Case-insensitively, because a case-sensitive comparison puts every capitalised name above every
lowercase one and that is not where a reader looks; with the raw names as a tiebreak so two spellings
of one word still order deterministically. Nothing in the comparison is locale-sensitive: an iPhone
and an iPad showing one worktree must show it identically.

The comparison is over the **compacted** name — what the row actually reads — rather than the first
component of the chain. The two differ only when a separator meets a punctuation character in a
sibling's name, and sorting a visible list by something other than its visible text is the harder
behaviour to explain.

