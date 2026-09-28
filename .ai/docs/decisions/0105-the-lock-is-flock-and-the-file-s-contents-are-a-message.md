# The lock is `flock`, and the file's contents are a message rather than a decision

A pid file whose contents decide who holds the lock gets the interesting case wrong. **A Granita that
crashed leaves a pid behind**, and the usual repair — check whether that process still exists — races
against the identifier being reused, so the failure mode is a lock nobody can take or one two
processes both take. The kernel already answers this exactly: a `flock` is released when the
descriptor closes, and a descriptor closes when the process dies however it dies. Asserted by a test
that writes a lock file naming a process that never existed and takes the lock anyway.

So the decision is the kernel's and the contents are only a name to put in the refusal — which is why
`heldBy` carries an **optional** holder. Whether the lock is taken and who has it can disagree for a
moment: a process that has just taken it has not yet written its name into it. A refusal that
softened into an acquisition on that window would be the two writers the lock exists to prevent, so
the name is what is lost and never the refusal. Advanced's row draws on "is blocked" rather than on
"has a holder" for the same reason — a row that vanished when the name could not be read would
disappear in exactly the case a reader has least to go on.

**`flock` rather than POSIX record locks, and that also decided how it is tested.** `fcntl` would
have handed back the holder's process identifier without reading any file, which is strictly better
information — but POSIX record locks are held per *process*, so a second lock taken inside one
process succeeds. The tests here simulate two processes by being two, in one test binary, which only
works because `flock` is per open file description. The holder is a constructor parameter rather than
something read from `ProcessInfo` inside the lock for the same reason.

**Outermost in the host chain**, outside `RebindingOnWake`. Inside it, the lock would be re-acquired
on every wake — a Mac that stops serving overnight because a `granita-server` was started in a
terminal in between. The lock is a fact about this launch, not about this bind.

