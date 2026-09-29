# The display-columns fixture was committed empty

`case-display-columns.diff` was 0 bytes from the day it was generated. The file it diffs is created
after the baseline commit and was never staged, and `git diff HEAD` shows an untracked file as
nothing at all — so the width arithmetic the entire viewer depends on had no coverage whatsoever.

`make verify-generated` could never have caught it: empty is deterministic, so committed-empty equals
regenerated-empty forever. The generator now stages the file and **asserts the fixture is non-empty**,
which is the check that was missing. The lesson generalises past this one file: a generator that only
proves it ran proves nothing about what it produced.

