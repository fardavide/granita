# The pinned trust replaces the system's evaluation and never runs beside it

macOS and iOS cap a TLS server certificate at 398 days and apply the cap **even to a certificate
handed to `SecTrust` as its own anchor** — Apple's published exemption covers roots a human
installed, not one set programmatically. SPEC §8's certificate lasts ten years, so the default policy
refuses it for its entire life.

A client that evaluated *and* compared the fingerprint would therefore refuse every Granita that has
ever existed, and the only symptom is a handshake that fails with nothing attached to it. So the
server-trust challenge is answered on the fingerprint alone: no `SecTrustEvaluateWithError`, no
policy, no chain. The key is the whole question, which is what SPEC §8 means by pinning.

This is asserted from both ends rather than commented. `ServerIdentityDomainTests` pins the refusal
itself — a real `SecTrust` under a real policy, expected to say "exceeds maximum temporal validity" —
so an OS that changes its mind turns a test red. And `PinnedServerTrustTests` judges a **ten-year**
`openssl`-generated certificate and expects it accepted, so anyone reintroducing default evaluation
beside the pin breaks that test rather than shipping a client that cannot connect to anything.

Rejected: evaluating first and pinning second, which is the shape every pinning tutorial shows and
which is wrong here for the reason above. Rejected too: shortening the certificate to 398 days so
both could run — it buys nothing, because pinning already makes expiry a backstop rather than a
schedule, and it would put a renewal on the calendar of an app whose whole point is that it is not
administered.

