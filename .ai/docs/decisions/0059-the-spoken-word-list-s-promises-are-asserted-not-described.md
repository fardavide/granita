# The spoken word list's promises are asserted, not described

The list documented four properties — a fixed count the 42-bit entropy argument depends on, no
duplicates, no two words a single letter apart, and no spelling contested across the Atlantic — and
nothing enforced any of them. It contained `amber` beside `ember`, which is the pair its own comment
names as the thing to avoid, and `bacon` beside `beacon`, which nobody had noticed at all.

They are now five tests over the list itself. The failure they prevent is not a build error: it is
somebody across a room reading six words aloud, months from now, and the wrong pairing being spent
once. `emerald` and `beetle` replace the two collisions.

Rejected: taking the list from a dictionary or from the PGP word list. The hand-picked constraint is
the point — the fallback exists for the case where the channel is a voice or a memory — and a
borrowed list would satisfy none of these four properties by accident.

