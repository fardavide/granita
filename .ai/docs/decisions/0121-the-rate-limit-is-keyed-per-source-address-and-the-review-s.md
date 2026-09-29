# The rate limit is keyed per source address, and the review's premise was one release stale

The return asks whether the limiter counts per device or per dialled address, having found
`request.head.authority` in the Mac round trip — the address the phone dialled, which is the same
string for every device, so five failures from anywhere would lock out everyone. Its copy was drawn
device-neutral to survive that being true.

It is not true any more. `GranitaRequestContext.source` is `remoteAddress?.ipAddress`, the peer's
address without its port, and it has been since the connection log needed a source worth reading. So
the limiter is **per device on any ordinary LAN**, and the kinder sentence is the one that ships:
*MacBook Pro has stopped taking pairing codes from this iPhone for a minute.*

Worth an entry only because of the shape: this is the second time a returned review has argued from a
premise the repository had already repaired — the Mac's plaintext warning was the first — and both
times the answer was to check the code rather than to build the drawing. A return is a recommendation.

