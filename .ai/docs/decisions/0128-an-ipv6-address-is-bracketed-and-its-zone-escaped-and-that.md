# An IPv6 address is bracketed and its zone escaped, and that was two routes rather than one

**This entry replaces one that said the opposite.** It recorded the defect below, argued that
degrading was honest enough for v1, and named the fix it was not doing. It was wrong on the size of
the hole: the same four lines are written three times, so the failure was never confined to the
words path — a Mac reached over IPv6 could not be *read from* either, which is a paired phone that
lists no worktrees. The fix is now built and this says what it does.

`NWPath`'s resolved endpoint stringifies an IPv6 address with its zone attached — `fe80::1%en0` —
and `URLComponents` will not take either half of that as a host: a bare literal's colons read as a
port separator, and a `%` is an escape that never was one. `components.url` comes out nil, so
`HttpServerPairing` **and** `HttpGranitaRepository` both fell back to their documented
nowhere-address, which is a `file://` URL handed to an HTTPS client. A Mac plainly sitting on the
desk was reported unreachable, twice, for two different reasons a reader would have read as one.

`ServerAddress.httpsUrl` is now the one place any of it is built, in `ClientConnectionData` beside
the two callers. RFC 6874 is the shape: the literal in square brackets, the zone's `%` written
`%25`, and it goes in through `percentEncodedHost` because the plain setter escapes the escape.
Whether an address is a literal at all is asked by looking for a colon, which a host name cannot
contain — no parsing, and nothing that a v4 address or a `.local` name takes a different path
through.

The nowhere-address fallback stays, and keeping it is the point of the change rather than an
oversight: a host that genuinely cannot go into a URL is a damaged scan, and *could not reach your
Mac* is the closest true thing this app can say about one. What was wrong was how much fell into
that sentence.

Kept from the entry this replaces, because the diagnosis is the expensive part: the symptom is
*could not reach your Mac* against a Mac that is plainly there, which reads exactly like a firewall
and costs an afternoon. Both routes are asserted for a literal with a zone and without one, and the
connection's own suite pins that the address arrives carrying the zone rather than being tidied on
the way through — an address that lost it names an interface nobody chose.

