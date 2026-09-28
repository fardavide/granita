# The X.509 encoder is ours, and the fourth dependency it beat was already in the graph

`swift-certificates` would have written the self-signed certificate in a dozen lines, and it is
**already resolved** — `swift-nio-extras` pulls it, so naming the product adds nothing to
`Package.resolved`. That is the same argument that admitted `NIOTransportServices`, and it was
rejected here.

The difference is what the dependency is *for*. `SPEC.md` §8 mandates the bind that only
NIOTransportServices can do, so that one is the spec's choice rather than a convenience. Nothing
mandates a certificate library, and "it happens to be in the graph today" is a property of
Hummingbird's transitive dependencies, not a decision this project made — the day nio-extras drops
it, a core capability acquires a real fourth dependency retroactively. The rule is that a fourth is
a conversation with Davide, and a conversation cannot be had by noticing something in a lockfile.

What was bought instead is a few hundred bytes of DER in a `Domain` module, whose output is checked
by **Security.framework itself** rather than by our own reader: the suite hands the certificate to
`SecCertificateCreateWithData`, matches the key inside it against the key that signed it, evaluates
it as its own anchor under a real TLS policy, and asserts the system's own hostname matcher against
a name the certificate covers and one it does not. A byte wrong anywhere and the signature does not
verify. The SPKI fingerprint is asserted against an `openssl`-produced vector rather than against
this encoder, because the whole failure mode is an encoder that agrees with itself.

