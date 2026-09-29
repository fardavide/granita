# What the first git slice deliberately leaves out

Two things from §5.3 are absent, and neither is an oversight.

**Resolving the git binary.** §5.1 wants `/usr/bin/git`, then `xcrun -f git`, then `PATH`, with a
clear error in the Mac UI when there is none. The middle step is itself a subprocess, so a locator
worth testing needs its own seam, and it belongs with the composition roots that will call it. Until
then the executable is a constructor parameter, and a path with no binary at it surfaces as git
being unavailable.

**`hash-object --stdin-paths`.** The only command that writes to a child's standard input, and the
only one with an unresolved correctness question: `--stdin-paths` reads one path per line, so a path
containing a newline needs C-quoting on the way in. That question belongs to §5.5's content hashing
rather than to the client, and adding the case later changes no signature.

