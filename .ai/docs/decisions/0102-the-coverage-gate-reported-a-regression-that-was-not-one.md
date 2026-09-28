# The coverage gate reported a regression that was not one, and the measurement was the defect

**The fifth time a falling row was read, it named the ratchet itself.** The four before it were
right — an undrawn tab's composition, a screen doing its own I/O, two predicates counting code a
picture cannot execute. This one was not: PR #35 failed on Unit 96.0% → 95.9% and All 96.9% → 96.8%,
and the whole of it was five lines in `SessionTranscript.swift`, a file that pull request does not
touch. A re-run of the identical commit passed.

**The evidence, because "flaky" is a claim and this needed to be a measurement.** Five runs of one
commit, in parallel: 96.121%, 96.121%, 96.037%, 96.037%, 96.037%. An earlier set of three moved
`SessionTranscript` between 81 and 86 covered lines of 87, and the five-run set moved
`BonjourBrowser` between 78 and 82. Serially, four runs still moved `BonjourServerDiscovery` by one
line. The suite is green in every one of them: what varies is which lines a scheduler reached before
something was torn down, never what a test asserts.

**Two causes, and both are fixed rather than tolerated.**

The first is a test that drove a real `NWBrowser` to answer a question about ordering. *Does the
screen say something before any browser has reported* is about what happens first, and it was being
asked of a daemon whose reply time is a property of the machine — so how much of
`BonjourServerDiscovery` and `BonjourBrowser` ran before the loop was left varied by run. It takes
the fake now, through a seam `DiscoverySession` already had and this type had hard-coded past. The
test passed either way, which is the point: **a percentage cannot describe this failure**, and the
test that answers the machine it runs on is exactly what `#33` was named for.

The second is the pass itself, which runs `--no-parallel` now. That is about the measurement rather
than the tests, and it is what takes the last of the variance out: with both changes, five runs of
one commit agree to the line and no file differs at all.

**Rejected: giving the gate slack.** A floor or a tolerance is the obvious fix and it is the wrong
one — it would buy a stable gate by making it stop noticing the thing it is for, and this repository
has four recorded instances of a one- or two-tenths move being a real defect. The gate is right to
have no slack; the number handed to it has to deserve that.

**The scope string is renamed for the fifth time, and this rename changes no predicate.** The four
before it moved which files the row was taken over; this one moves how the number is taken, and the
gate's un-judging mechanism is the only one there is — it compares two numbers when both were taken
the same way. It also passes the test those four are held to: it does **not** flatter the row.
95.978% replaces a parallel sample that read up to 96.121%, because what is lost is coverage that
was never the tests' to claim.

