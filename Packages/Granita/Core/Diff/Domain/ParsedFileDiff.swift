import Foundation

/// One file's section of a unified diff, holding what the diff text itself states and nothing else.
///
/// Deliberately not a `FileChange`: status, stats and content hashes come from one comparison run
/// with identical options, and re-deriving any of them from the diff text would be the second
/// disagreeing source the git layer exists to avoid. What only the diff text knows is where the
/// content is, whether git refused to diff it, and whether it is a gitlink.
public struct ParsedFileDiff: Hashable, Sendable {

    /// Repo-relative, POSIX separators. For a deleted file, the path it had.
    public let path: String

    /// Set only when the file arrived under a different name, so a consumer never has to compare it
    /// against `path` to find out whether this was a rename.
    public let oldPath: String?

    /// Git refused to diff the content, either as a one-line summary or as a `GIT binary patch`.
    public let isBinary: Bool

    /// A gitlink — mode 160000. Its hunks are two `Subproject commit` lines, not source.
    public let isSubmodule: Bool

    /// Empty when there is nothing to show: a mode change, a binary file, or a rename with no edits.
    public let hunks: [Hunk]

    public init(path: String, oldPath: String?, isBinary: Bool, isSubmodule: Bool, hunks: [Hunk]) {
        self.path = path
        self.oldPath = oldPath
        self.isBinary = isBinary
        self.isSubmodule = isSubmodule
        self.hunks = hunks
    }
}
