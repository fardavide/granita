import Foundation

/// Where a file sits inside a checkout, in the bytes git reported it as.
///
/// Bytes are the primitive and text is the projection, which is the opposite of the comfortable
/// arrangement and is deliberate. A path on disk is a sequence of bytes with no encoding attached;
/// macOS discourages invalid UTF-8 but accepts it, and an agent writing files from a script will
/// eventually produce one. Decoding on the way in and re-encoding on the way out would address a
/// different file — silently, because the replacement character is a perfectly valid filename
/// character.
public struct RepositoryRelativePath: Hashable, Sendable {

    public let bytes: Data

    public init(bytes: Data) {
        self.bytes = bytes
    }

    public init(_ text: String) {
        bytes = Data(text.utf8)
    }

    /// The path as text, with anything undecodable replaced.
    ///
    /// For display and for the wire, never for re-invoking git.
    public var text: String {
        String(decoding: bytes, as: UTF8.self)
    }
}
