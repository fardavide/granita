import CryptoKit
import Foundation

// CryptoKit here for the same reason `CoreDiffDomain` gives: it is pure computation on both
// platforms, and the alternative is a hand-rolled SHA-256 in the one place where being subtly
// wrong cannot be seen by reading it.

/// What the phone pins a Mac by: the base64 of the SHA-256 of its certificate's
/// SubjectPublicKeyInfo.
///
/// The public key rather than the whole certificate, deliberately. A certificate carries dates and
/// names that a Mac may legitimately need to reissue; the key is the thing that must not change,
/// and pinning the narrower fact is what lets the wider one move.
///
/// Opaque and typed, like every other identifier here, because the one thing that must never happen
/// is a fingerprint being compared against a string that is not one.
public struct SpkiFingerprint: Hashable, Sendable, RawRepresentable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Over the DER of the SubjectPublicKeyInfo structure — the whole `SEQUENCE`, algorithm
    /// identifier included, not the bare public key point. That is what `openssl … -pubout -outform
    /// DER` writes and what every other pinning implementation hashes, so a Granita that hashed
    /// only the point would be pinning something nothing else in the world agrees with.
    public init(subjectPublicKeyInfoDer: some DataProtocol) {
        rawValue = Data(SHA256.hash(data: subjectPublicKeyInfoDer)).base64EncodedString()
    }

    /// Whether this is the same fingerprint, compared in time that does not depend on where two
    /// differ.
    ///
    /// `==` would do the same job and return on the first differing character. Both sides here are
    /// public — a fingerprint is printed in a QR code — so the leak is not of a secret, but the
    /// comparison sits in the handshake path of a server on the same LAN as whoever is measuring it,
    /// and a compare that walks a prefix is the shape an attacker builds a matching key against.
    /// Cheap to do properly, so it is done properly.
    ///
    /// The length is not secret: a SHA-256 digest in base64 is always the same width, and a value
    /// that is not is not a fingerprint at all.
    public func matches(_ other: Self) -> Bool {
        let mine = Array(rawValue.utf8)
        let theirs = Array(other.rawValue.utf8)
        guard mine.count == theirs.count, mine.isEmpty == false else {
            return false
        }
        var difference: UInt8 = 0
        for index in mine.indices {
            difference |= mine[index] ^ theirs[index]
        }
        return difference == 0
    }
}
