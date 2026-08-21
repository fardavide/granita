import CryptoKit
import Foundation

// CryptoKit is the one framework this Domain module imports, and it is a deliberate reading of the
// layer rule rather than an oversight. The rule exists to keep Domain free of I/O and of platform
// coupling; CryptoKit is pure computation, ships on both platforms, and the alternative is a
// hand-rolled SHA-256 — which would be more code, in the one place where being subtly wrong is
// undetectable by reading it. Nothing else in Domain may follow this precedent without saying why.

/// A hash used as an opaque address.
///
/// Every identifier the API accepts is one of these rather than a filesystem path. That is the
/// single most important rule in the API: the server streams private source code, and a path
/// parameter would be a directory traversal hole. Derivation lives here so both sides agree on it,
/// but only the server ever derives — the client receives identifiers and hands them back.
///
/// **On the wire each of these is a bare string**, not an object with a `rawValue` inside it. The
/// wrapper is a compile-time distinction between three kinds of hash that would otherwise all be
/// `String`; it is not a shape the wire owes anyone, and a string is what an identifier has to be
/// to serve as a path component in a URL and as a key in a JSON object. `RawRepresentable` is what
/// spells that, and `CodingKeyRepresentable` is what keeps a dictionary keyed by one from encoding
/// as a flat array of alternating keys and values.
private enum OpaqueIdentifier {

    /// SHA-256 over a domain-separated input, truncated to 32 hex characters.
    ///
    /// The domain prefix is what stops a project and its own primary worktree — which are the same
    /// path — hashing to the same value. Without it the two would be interchangeable, and the type
    /// system's guarantee that they are not would end at the wire.
    static func derive(domain: String, from bytes: Data) -> String {
        var input = Data("\(domain):".utf8)
        input.append(bytes)
        return SHA256.hash(data: input)
            .prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func derive(domain: String, from text: String) -> String {
        derive(domain: domain, from: Data(text.utf8))
    }
}

/// Addresses a git repository the user has explicitly enabled.
public struct ProjectID: RawRepresentable, CodingKeyRepresentable, Hashable, Codable, Sendable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(canonicalPath: String) {
        rawValue = OpaqueIdentifier.derive(domain: "project", from: canonicalPath)
    }
}

/// Addresses one checkout of a repository — the primary one, or a linked worktree.
public struct WorktreeID: RawRepresentable, CodingKeyRepresentable, Hashable, Codable, Sendable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(canonicalPath: String) {
        rawValue = OpaqueIdentifier.derive(domain: "worktree", from: canonicalPath)
    }
}

/// Addresses a changed file within a worktree.
public struct FileID: RawRepresentable, CodingKeyRepresentable, Hashable, Codable, Sendable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(repositoryRelativePath: String) {
        rawValue = OpaqueIdentifier.derive(domain: "file", from: repositoryRelativePath)
    }

    /// Derives from raw bytes.
    ///
    /// Paths on disk are bytes and are not necessarily valid UTF-8; git will hand us such a path
    /// eventually. Hashing must not be the step that fails on it, so the byte form is the primitive
    /// and the string form is the convenience.
    public init(repositoryRelativePathBytes bytes: Data) {
        rawValue = OpaqueIdentifier.derive(domain: "file", from: bytes)
    }
}
