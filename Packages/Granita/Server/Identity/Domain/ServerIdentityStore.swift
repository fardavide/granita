import Foundation

/// Where the identity this Mac serves under is kept between runs.
///
/// Behind a protocol because the Keychain is reachable from no host test: a SwiftPM test binary is
/// unsigned and has no keychain of its own, so the real conformer can only be exercised by running
/// the app. Everything that consumes an identity is exercised against a fake instead, which is what
/// keeps the untestable part down to one file.
public protocol ServerIdentityStore: Sendable {

    /// The identity, generated on first run and returned unchanged on every run after it.
    ///
    /// **Unchanged is the contract.** The phone pins this key, so regenerating — because the Mac
    /// changed network, say, and its addresses no longer match the certificate's — would silently
    /// unpair every device that had ever connected. A stale address in a subject alternative name
    /// costs nothing by comparison: the client matches on the pinned key, not on the name.
    func identity() async throws(ServerIdentityError) -> ServerIdentity
}

/// What a *new* identity should claim. Read only when one is generated, which is once.
public struct IdentitySubject: Hashable, Sendable {

    public let commonName: String
    public let subjectAlternativeNames: [SubjectAlternativeName]

    public init(commonName: String, subjectAlternativeNames: [SubjectAlternativeName]) {
        self.commonName = commonName
        self.subjectAlternativeNames = subjectAlternativeNames
    }
}

public enum ServerIdentityError: Error, Hashable, Sendable {

    /// A name or address the certificate encoding cannot carry.
    case malformedSubject(reason: String)

    case notSignable(reason: String)

    /// The Keychain refused, carrying the `OSStatus` and what was being attempted.
    ///
    /// Both, because the status alone is a number nobody can act on and the operation alone does
    /// not say whether this was a locked keychain, a duplicate item or a missing entitlement —
    /// and the person who can fix any of those is standing at the Mac.
    case keychainRefused(operation: String, status: Int32)

    /// Something is in the Keychain under this name that cannot be served with — a certificate
    /// whose private key is gone, most likely, which is what a half-removed identity looks like.
    case identityUnusable(reason: String)
}

extension ServerIdentityError {

    /// The same fault, in words, for the person standing at this Mac.
    ///
    /// Here rather than at each of the two places that show it, because they show it about one
    /// thing: an identity this Mac cannot read stops it serving **and** stops it offering a pairing
    /// code, and a reader meeting both should not be handed two vocabularies for one fault.
    public var explanation: String {
        switch self {
        case .malformedSubject(let reason):
            "this Mac's name or addresses cannot go in a certificate: \(reason)"
        case .notSignable(let reason):
            "the identity could not be signed: \(reason)"
        case .keychainRefused(let operation, let status):
            "the Keychain refused while \(operation) (\(status)) — unlock the login keychain"
        case .identityUnusable(let reason):
            reason
        }
    }
}
