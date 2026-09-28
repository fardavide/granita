# Compaction folds directories, never a file, and the row is identified by its deepest path

`app/src/main/kotlin/com/example` is one row because each of those directories holds exactly one
child and that child is another directory. A directory whose only child is a **file** is left alone:
the file is content the row contains, not another step of the path, and folding it in would leave
nowhere to render its status, stats and checkbox.

A compacted row is identified by the **deepest** directory in its chain, because that is the row
collapse state has to be remembered against — the chain collapses and expands as the single thing the
reader sees. Its name keeps the separators; its path is the full repo-relative one.

Considered and deferred: aggregate `+n / -m` on a directory row, which a collapsed directory could
usefully show. §10 asks for stats on file rows only, and the aggregate is a sum over a subtree that
the view layer can take when a design asks for it.

