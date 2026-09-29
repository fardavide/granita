# There is no manual host entry, which is a departure from `SPEC.md` §10

§10 asks for "manual host entry as fallback" beside Bonjour discovery. There is none, and there will
not be one in v1.

The words screen is reachable only from a browse result, so the host and port are already in hand
before a reader could type anything — the input genuinely missing from that path is the key, not the
address, which is the entry two above. And a field that lets a reader point this app at an address
Bonjour never returned is not a fallback: combined with the entry two above it is a way to hand a
pairing code to any address somebody can be talked into typing, which is a strictly worse hole than
the one trust on first use accepts.

The weakest departure recorded here, and deliberately so: §0 lists Bonjour-plus-QR as **PROPOSED,
override freely** rather than LOCKED, so this is a proposal being narrowed rather than a decision
being overturned. It is written down anyway, because "the spec says do X and we did not" is exactly
what this file is for.

