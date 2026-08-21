import CryptoKit
import Foundation

/// Whether a certificate offered during a handshake belongs to the Mac this phone paired with.
///
/// **This replaces the default TLS evaluation rather than adding to it**, and that is the single
/// decision the whole of Granita's transport security rests on. macOS and iOS cap a server
/// certificate at 398 days and apply the cap even to one handed to `SecTrust` as its own anchor —
/// Apple's published exemption covers roots a human installed, not one set programmatically. SPEC
/// §8's certificate lasts ten years, so the default policy refuses it for its entire life;
/// `ServerIdentityDomainTests` asserts that refusal against the real policy so that an OS which
/// changes its mind turns a test red rather than leaving a comment nobody re-reads.
///
/// A client that evaluated *and* pinned would therefore refuse every Granita that has ever existed,
/// and the only symptom is a handshake that fails with nothing attached. So there is no evaluation
/// here to combine with, no `SecTrustEvaluateWithError`, and no policy: the key is the whole
/// question, which is also what SPEC §8 means by pinning.
///
/// Kept in `Domain` and given a public key rather than a `SecTrust` so that the decision is a pure
/// function over bytes. What is left in the `Data` delegate — read the leaf key, call this, turn the
/// answer into a disposition — is the part only a device can prove, and it is three lines.
public enum PinnedTrust {

    /// The leaf key as `SecKeyCopyExternalRepresentation` hands it back, judged against the
    /// fingerprint the pairing link carried.
    ///
    /// The X9.63 point is re-encoded into a `SubjectPublicKeyInfo` by CryptoKit rather than
    /// assembled here, because that is the encoding the Mac hashed when it wrote the link. Two
    /// implementations of one structure is how a fingerprint comes to disagree with itself.
    public static func isTrusted(leafPublicKeyX963: some ContiguousBytes, against pinned: SpkiFingerprint) -> Bool {
        guard let key = try? P256.Signing.PublicKey(x963Representation: leafPublicKeyX963) else {
            // Not a P-256 point, so not a key this Mac could have served. Refused rather than
            // thrown: a handshake the phone cannot make sense of is one it declines, and no reader
            // could act on the difference.
            return false
        }
        return pinned.matches(SpkiFingerprint(subjectPublicKeyInfoDer: key.derRepresentation))
    }
}
