import Foundation

import CorePairingDomain

/// The certificate this Mac serves under, as everything but the TLS stack needs to see it.
///
/// The private half is deliberately absent. It lives in the Keychain and never leaves it, so what
/// travels through the app is this — the bytes a client would be shown, and the fingerprint it
/// would pin them by.
public struct ServerIdentity: Hashable, Sendable {

    public let certificateDer: [UInt8]

    /// What goes in the pairing link, and what the phone compares every later handshake against.
    public let fingerprint: SpkiFingerprint

    // The names this certificate covers are deliberately absent. They are settled once, when it is
    // generated, and after that the only copy that matters is the one inside `certificateDer` —
    // carrying a second would let the two disagree about a certificate loaded from the Keychain
    // years later, and it is the certificate that clients read.

    public let commonName: String

    public let notBefore: Date
    public let notAfter: Date

    public init(
        certificateDer: [UInt8],
        fingerprint: SpkiFingerprint,
        commonName: String,
        notBefore: Date,
        notAfter: Date
    ) {
        self.certificateDer = certificateDer
        self.fingerprint = fingerprint
        self.commonName = commonName
        self.notBefore = notBefore
        self.notAfter = notAfter
    }

    /// SPEC §8's ten years, counted in days rather than through a calendar.
    ///
    /// A decade holds two or three leap days depending on where it starts, and nothing here depends
    /// on which: the certificate is pinned by its key, so its expiry is a backstop rather than a
    /// schedule. Counting days keeps this a value a test can write down.
    public static let tenYears: TimeInterval = 3653 * 24 * 60 * 60
}

/// A way this Mac can be reached, as the certificate claims it.
public enum SubjectAlternativeName: Hashable, Sendable {

    /// A name — `macbook-pro.local`, the one Bonjour publishes.
    case dnsName(String)

    /// An address, for when mDNS is not bridged between two segments of a network and the name
    /// does not resolve. That is not hypothetical here: Davide's Mac is wired and his phone is not.
    case ipAddress(IpAddress)
}

/// An IP address, as the bytes a certificate carries.
///
/// Bytes rather than text, because that is what the encoding wants and because parsing text into
/// them would be a second place for an address to be wrong. Whoever builds one has it in this form
/// already — the system reports interfaces as bytes.
public struct IpAddress: Hashable, Sendable, CustomStringConvertible {

    /// Four bytes for an IPv4 address, sixteen for an IPv6 one, most significant first.
    public let bytes: [UInt8]

    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    public var description: String {
        switch bytes.count {
        case 4:
            bytes.map(String.init).joined(separator: ".")
        case 16:
            stride(from: 0, to: 16, by: 2)
                .map { String(format: "%02x%02x", bytes[$0], bytes[$0 + 1]) }
                .joined(separator: ":")
        default:
            // Not an address any certificate will accept, and the builder refuses it — but a value
            // printed while diagnosing that is more useful than a crash inside the diagnosis.
            bytes.map { String(format: "%02x", $0) }.joined()
        }
    }
}
