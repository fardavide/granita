import CoreDiffDomain
import Foundation

/// A changed file, as the file selector addresses it and places it.
///
/// The two fields are all the tree needs: an opaque identifier to hand back when a row is tapped,
/// and where the file sits. Everything else a row renders — status, stats, viewed state — is
/// per-file state that churns while the shape of the tree does not, so it is joined by identifier
/// one layer up rather than embedded in the structure.
public struct FileTreeEntry: Hashable, Sendable {

    public let id: FileID

    /// Repo-relative, POSIX separators. Content, never an input to the API.
    public let path: String

    /// What the file's row reads: the last path component, because the directories above it are
    /// rows of their own.
    public var name: String {
        String(path.split(separator: "/").last ?? "")
    }

    public init(id: FileID, path: String) {
        self.id = id
        self.path = path
    }
}

/// One row of the file selector.
public enum FileTreeNode: Hashable, Sendable {
    case directory(FileTreeDirectory)
    case file(FileTreeEntry)
}

/// A directory row, which may stand for a whole chain of directories rather than one.
public struct FileTreeDirectory: Hashable, Sendable {

    /// What the row reads. A compacted chain keeps its separators, so
    /// `app/src/main/kotlin/com/example` is one row rather than five.
    public let name: String

    /// Repo-relative path of the **deepest** directory the row stands for.
    ///
    /// This is the row's identity, and it is what collapse state is remembered against — a
    /// compacted chain collapses and expands as the single row it renders as.
    public let path: String

    public let children: [FileTreeNode]

    public init(name: String, path: String, children: [FileTreeNode]) {
        self.name = name
        self.path = path
        self.children = children
    }
}
