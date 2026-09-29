# macOS refuses a ten-year TLS certificate, which is why pinning replaces evaluation

Apple's 398-day cap on TLS server certificates is documented as not applying to roots a human
added. It **does** apply to one handed to `SecTrust` programmatically as its own anchor: evaluated
under `SecPolicyCreateSSL`, the ten-year identity comes back
`Certificate exceeds maximum temporal validity period` however correct everything else about it is.

So SPEC §8's ten years and SPEC §8's pinning are one decision rather than two, and it matters for
M4: the phone's `URLSessionDelegate` must **replace** the default evaluation with a fingerprint
comparison, not run both. A client that did both would refuse every Granita there has ever been,
and the only symptom would be a handshake that fails.

Found by running it, and now asserted by a test that expects that exact refusal — so a macOS which
changes its mind turns the suite red rather than leaving a comment nobody re-reads.

