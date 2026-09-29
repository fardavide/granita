# The address conversion is public so that all four of its answers can be decided by a test

`LocalAddresses.current()` reports whatever this machine has up at the instant it is called, which
makes it a poor thing to assert against and a worse thing to measure. Its IPv6 branch ran only when
an IPv6 address happened to be up, and the **link-local rejection ran only when one happened to be
link-local** — so the one case with a consequence a reader would ever meet, a certificate naming an
address that matches nothing, was covered by luck rather than by a test. The unsupported-family
branch, which in production runs on every interface a Mac has because every interface reports a
link-layer address alongside its IP ones, was asserted by nothing at all.

Davide chose fixing the nondeterminism over widening the coverage gate, and the split is the fix:
the enumeration stays what it honestly is — a smoke test against the real machine, which is the only
thing that can say `getifaddrs` still works — and the pure conversion becomes
`certifiableAddress(of:)`, fed fixed `sockaddr_in` and `sockaddr_in6` values.

**Public rather than `@testable`.** Nothing in this repository imports a module that way, and
starting here would buy one test's convenience with a convention. The function is also a nameable
unit on its own terms: it answers *what address, if any, can a certificate carry here*, which is why
a link-layer address and a link-local one both come back as nothing.

**It cannot move to `Domain`.** `sockaddr` is Darwin's, and a `Domain` target sees Foundation and no
framework. So it stays in `Data` beside the enumeration that feeds it.

**The boundary cases are the point, and they were confirmed to fail.** Link-local is `fe80::/10`, so
what decides it is the top two bits of the second byte rather than the whole byte — `febf::1` is the
last address inside the range and `fec0::1` the first outside. Rewriting the guard as
`read[1] != 0x80`, which is the plausible wrong version, turns the `febf::1` case red and leaves
everything else green. A test that only ever tried `fe80::1` would have passed against both.

### A reader that has gone away is dropped on the next write, not by announcing its own departure

Found by the artifact above, on the first pull request that had it. `InMemoryConnectionLog` removed a
finished reader from an `onTermination` closure that hopped through a detached `Task`, and whether
that task ran before a test process stopped writing its profile was a **race**. It won on this laptop
and lost on the runner, which surfaced as the Unit and All region rows each falling 0.1% on a branch
that had touched nothing anywhere near it — the kind of red that reads as "the gate is mis-scoped"
and is neither that nor a real regression.

`record` now prunes readers whose `yield` reports `.terminated`. That is synchronous, sits on the one
path every test in that suite already drives, and deletes two regions rather than making them
reachable: the closure and the private removal are both gone. What it costs is that a finished
continuation is held until the next attempt is recorded, which is a `UUID` and a continuation.

**This is the same defect as the one the pull request was about**, arriving in a second file — a
region whose coverage is decided by the machine rather than by a test. Recorded together because the
tool that found it is the artifact added to diagnose the first, and because the pattern generalises:
an asynchronous cleanup path with no observable consequence cannot be asserted, only raced.

Rejected: exposing the reader count so a test could wait for the removal. It is state nothing else
reads, so it would be API a test alone justifies — and it would have kept the race and merely made it
survivable, rather than removing it.

### And a third instance, in the one place the product cannot afford it

The same read found `GitInvocation.quotedIfNeeded`'s escape table covered on this laptop and not on
the runner. It was not a measurement artefact: of the four escapes git's C-quoting needs, **only the
newline had a test.** The carriage return, the backslash and the double quote were reached, when they
were reached at all, by whatever paths happened to exist in a fixture repository — so a runner with a
slightly different checkout exercised a different subset, and the row moved for reasons no one had
written.

The gap matters more than the number. `--stdin-paths` unquotes a line with C escapes once it begins
with a double quote, so a backslash left bare is read as the start of an escape and **the path git
hashes is not the path on disk**. That is a wrong content hash, and a wrong content hash silently
un-marks a file the reader had marked viewed — a defect with no error anywhere, on the one mechanism
SPEC §5.5 exists to make trustworthy.

`standardInput(for:)` is a pure function over bytes, so all four escapes and the leading-quote
trigger are now asserted with no filesystem, no git and no fixture. The file went from 49 of 54
regions on the runner to 54 of 54 everywhere.

**Three files, one defect.** A pure function reachable only through something that varies by machine
is not tested, however green the suite looks — and the coverage row saying so was read as noise twice
before the export was there to settle it.

