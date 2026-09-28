# The git client asks a closed set of questions, not an arbitrary command line

The obvious shape for "run git" is a subcommand and a list of arguments. It was rejected. The
questions the product asks are fixed by SPEC §5.3 and each carries a flag whose absence is a defect
that produces no error — so they are an enumeration, and the argument vector for each is built in
one place that a test reads as an array.

Two things follow that are worth stating because they look like omissions.

**No exit code reaches the success path.** Two commands answer by failing — `git diff` exits 1 when
it found differences, `rev-parse --verify --quiet HEAD` exits 1 in a repository with no commits —
and the temptation is to hand the caller the code and let it decide. Instead each command declares
which codes count as having answered, and an unborn HEAD is simply an empty answer. What a caller
gets back is bytes and whether they are all of them. That keeps the exit code, which is a fact about
a subprocess, out of a protocol whose whole purpose is that it need not be one.

**The error is allowed to be more concrete than the success path**, and carries git's standard error
verbatim along with the exit code. It is read on a phone by someone who cannot open a terminal, and
a failure that arrives as a bare code is a failure nobody can act on.

