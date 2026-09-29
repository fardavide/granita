# An output cap truncates, and truncating means killing git

§5.4 wants a diff that is too large shown as a prefix with a flag, not refused. So the cap is not an
error: the client returns what it read and says it is a prefix.

Stopping the read is only half of enforcing it. A macOS pipe buffers 64 KiB and the cap permits two
megabytes, so git is still writing into a pipe nobody is emptying and blocks there forever — the
hang is on exactly the large diffs the guard exists for. The process is torn down as part of hitting
the cap, which in turn means a truncated run's termination status describes our own signal and must
not be judged: judging it would turn every large diff into a failure.

The same teardown serves the timeout, and neither ever signals a process **group** — a child gets
this process's own group, so signalling the group signals the menu bar app.

