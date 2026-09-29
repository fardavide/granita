# The client reconstructs the public key info rather than parsing the certificate

The fingerprint is taken over the whole `SubjectPublicKeyInfo` structure, which is what the Mac
hashed and what every other pinning implementation in the world agrees on. Getting those exact bytes
back on the phone could be done two ways: parse the leaf certificate's DER, or read the key out with
`SecCertificateCopyKey` and let CryptoKit re-encode it.

CryptoKit re-encodes. `SecKeyCopyExternalRepresentation` hands back the X9.63 point, and
`P256.Signing.PublicKey(x963Representation:).derRepresentation` produces byte-for-byte the structure
the Mac hashed with the same call. There is one implementation of that encoding on both sides, which
is the property that matters: two implementations of one structure is how a fingerprint comes to
disagree with itself.

Rejected: promoting `DerValue` to a `Core` module so the client could share it. It is a *writer* —
"just enough DER to write one certificate" — so sharing it would have meant writing a DER *reader*
that does not exist, to recover bytes that a two-line round trip already returns exactly. A module
move and a new parser, for nothing.

