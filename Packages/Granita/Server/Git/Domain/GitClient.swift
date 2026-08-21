import Foundation

/// Everything this product knows about git, behind one call.
///
/// One of the three abstractions the architecture permits without a second implementation behind it
/// today. Git is reached through a subprocess because git is the source of truth for worktrees and
/// for index state and a library binding diverges exactly there; this protocol is what would let a
/// library-based backend replace that decision later without a call site moving, which is what
/// keeps a sandboxed build on the table.
public protocol GitClient: Sendable {

    /// Asks git something, in a checkout.
    ///
    /// The location is a directory on this Mac, never anything the API accepted from a client: the
    /// phone addresses a worktree by identifier and the server resolves it against its own registry
    /// of enabled projects. That is the security boundary rather than a convention.
    func run(_ command: GitCommand, in location: RepositoryLocation) async throws(GitError) -> GitOutput
}

/// What git said.
public struct GitOutput: Hashable, Sendable {

    /// Bytes, because most of what git is asked here is NUL-separated and some of it is a path that
    /// does not decode.
    public let standardOutput: Data

    /// Whether this is a prefix of what git had to say rather than all of it.
    ///
    /// Carried rather than thrown: a diff too large to hold is still a diff worth showing the first
    /// part of, and the size guards exist to show it rather than to refuse.
    public let isTruncated: Bool

    public init(standardOutput: Data, isTruncated: Bool) {
        self.standardOutput = standardOutput
        self.isTruncated = isTruncated
    }
}

/// Where a checkout lives on this Mac.
public struct RepositoryLocation: Hashable, Sendable {

    public let path: String

    public init(path: String) {
        self.path = path
    }
}
