import Foundation

// The models the API is expressed in. Every one is Sendable, Codable and Hashable, and every
// Codable key is camelCase on both sides — these types are the wire contract, so a renamed property
// is a version skew rather than a refactor.

/// How many files moved, and by how much.
public struct ChangeStats: Hashable, Codable, Sendable {

    public let filesChanged: Int
    public let insertions: Int
    public let deletions: Int

    public init(filesChanged: Int, insertions: Int, deletions: Int) {
        self.filesChanged = filesChanged
        self.insertions = insertions
        self.deletions = deletions
    }

    public static let zero = ChangeStats(filesChanged: 0, insertions: 0, deletions: 0)

    public static func + (lhs: ChangeStats, rhs: ChangeStats) -> ChangeStats {
        ChangeStats(
            filesChanged: lhs.filesChanged + rhs.filesChanged,
            insertions: lhs.insertions + rhs.insertions,
            deletions: lhs.deletions + rhs.deletions
        )
    }
}

/// What happened to a file between HEAD and the working tree.
///
/// `copied` is deliberately absent: detecting copies needs `--find-copies`, which is expensive, and
/// it is never passed.
public enum FileStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case added
    case modified
    case deleted
    case renamed
    case typeChanged
    case untracked
    case conflicted
}

/// What a single line within a hunk represents.
public enum DiffLineKind: String, Codable, Hashable, Sendable, CaseIterable {
    case context
    case addition
    case deletion

    /// `\ No newline at end of file`. Rendered, never counted as content.
    case noNewlineMarker

    /// One of `<<<<<<<`, `=======`, `>>>>>>>`.
    ///
    /// A conflicted path diffs as an ordinary unified diff carrying these inline rather than as a
    /// combined `diff --cc`, so the parser tags them and the client renders them distinctly.
    case conflictMarker
}

/// A run of characters within a line, and whether it is part of what changed.
public struct WordSegment: Hashable, Codable, Sendable {

    public let text: String
    public let isChanged: Bool

    public init(text: String, isChanged: Bool) {
        self.text = text
        self.isChanged = isChanged
    }
}

/// One line of a hunk.
public struct DiffLine: Hashable, Codable, Sendable {

    public let kind: DiffLineKind

    /// Line number on the HEAD side, absent for an addition.
    public let oldNumber: Int?

    /// Line number in the working copy, absent for a deletion.
    public let newNumber: Int?

    /// The content, without the leading `+`, `-` or space. CRLF is preserved verbatim.
    public let text: String

    /// Tab-expanded, East-Asian-width-aware column count.
    ///
    /// Carried on the wire rather than computed by the client because the wrap arithmetic in the
    /// viewer depends on it, and because the parser is the only place that sees the line before it
    /// has been through a text engine.
    public let displayColumns: Int

    /// Whether `displayColumns` is a best-effort value the client should replace by measuring the
    /// line for real.
    ///
    /// Set for anything outside the predictable set — emoji, ZWJ sequences, unusual scripts. Carried
    /// rather than re-derived on the client because both sides would otherwise implement the same
    /// Unicode judgement and could disagree, and a disagreement here is a row-count error in the
    /// scroll. A plain `Bool` rather than an optional: an absent key that means false is the exact
    /// ambiguity the API's PATCH body already has to work around.
    public let needsMeasurement: Bool

    /// Populated only for add and delete lines that were paired for an intra-line diff.
    public let segments: [WordSegment]?

    public init(
        kind: DiffLineKind,
        oldNumber: Int?,
        newNumber: Int?,
        text: String,
        displayColumns: Int,
        needsMeasurement: Bool = false,
        segments: [WordSegment]?
    ) {
        self.kind = kind
        self.oldNumber = oldNumber
        self.newNumber = newNumber
        self.text = text
        self.displayColumns = displayColumns
        self.needsMeasurement = needsMeasurement
        self.segments = segments
    }
}

/// A contiguous run of changed lines with its surrounding context.
public struct Hunk: Hashable, Codable, Sendable {

    public let index: Int
    public let oldStart: Int
    public let oldCount: Int
    public let newStart: Int
    public let newCount: Int

    /// Whatever git put after the closing `@@` — usually the enclosing function.
    public let sectionHeading: String?

    public let lines: [DiffLine]

    public init(
        index: Int,
        oldStart: Int,
        oldCount: Int,
        newStart: Int,
        newCount: Int,
        sectionHeading: String?,
        lines: [DiffLine]
    ) {
        self.index = index
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.sectionHeading = sectionHeading
        self.lines = lines
    }
}

/// One changed file, as the change set reports it.
///
/// Everything here comes from the single comparison the git layer runs, except the three fields
/// that cannot: `contentHash` is derived per §5.5, `isViewed` is the reader's own state, and
/// `language` is a hint for the highlighter taken from the extension.
public struct FileChange: Hashable, Codable, Sendable {

    public let id: FileID

    /// Repo-relative, POSIX separators, decoded lossily from the bytes git reported.
    public let path: String

    /// Set only for a rename, so nobody has to compare it against `path` to find out.
    public let oldPath: String?

    public let status: FileStatus
    public let isBinary: Bool
    public let isSubmodule: Bool
    public let stats: ChangeStats

    /// 64 hex characters over the file's status and its three object ids, so a file marked viewed
    /// becomes unviewed the moment the agent touches it again.
    public let contentHash: String

    /// Diff lines, near enough for the client to reserve scroll space before the diff arrives.
    public let estimatedLineCount: Int

    public let isViewed: Bool

    /// Whether the file's diff will come back as a prefix, known before it is asked for.
    public let isTruncated: Bool

    /// A hint for the highlighter, inferred from the extension. Absent when nothing is claimed.
    public let language: String?

    public init(
        id: FileID,
        path: String,
        oldPath: String?,
        status: FileStatus,
        isBinary: Bool,
        isSubmodule: Bool,
        stats: ChangeStats,
        contentHash: String,
        estimatedLineCount: Int,
        isViewed: Bool,
        isTruncated: Bool,
        language: String?
    ) {
        self.id = id
        self.path = path
        self.oldPath = oldPath
        self.status = status
        self.isBinary = isBinary
        self.isSubmodule = isSubmodule
        self.stats = stats
        self.contentHash = contentHash
        self.estimatedLineCount = estimatedLineCount
        self.isViewed = isViewed
        self.isTruncated = isTruncated
        self.language = language
    }
}

/// One file's diff, and enough about the file's size for the client to know whether more exists.
public struct FileDiff: Hashable, Codable, Sendable {

    public let file: FileChange
    public let hunks: [Hunk]

    /// Total lines on each side, which is what makes "can this hunk expand downwards" answerable
    /// without asking the server.
    public let oldLineCount: Int
    public let newLineCount: Int

    public let isTruncated: Bool

    /// Why, in words a reader can act on, and only when `isTruncated`.
    public let truncationReason: String?

    public init(
        file: FileChange,
        hunks: [Hunk],
        oldLineCount: Int,
        newLineCount: Int,
        isTruncated: Bool,
        truncationReason: String?
    ) {
        self.file = file
        self.hunks = hunks
        self.oldLineCount = oldLineCount
        self.newLineCount = newLineCount
        self.isTruncated = isTruncated
        self.truncationReason = truncationReason
    }
}

/// A repository the user has explicitly enabled.
///
/// Explicitly is the operative word: nothing is served that was not added by hand, which is what
/// makes an opaque identifier resolvable against a registry rather than against the filesystem.
public struct Project: Hashable, Codable, Sendable {

    public let id: ProjectID
    public let name: String
    public let isVisible: Bool
    public let worktreeCount: Int
    public let dirtyWorktreeCount: Int

    public init(id: ProjectID, name: String, isVisible: Bool, worktreeCount: Int, dirtyWorktreeCount: Int) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.worktreeCount = worktreeCount
        self.dirtyWorktreeCount = dirtyWorktreeCount
    }
}

/// One checkout of a project.
public struct Worktree: Hashable, Codable, Sendable {

    public let id: WorktreeID
    public let projectId: ProjectID
    public let projectName: String

    /// The short branch name, absent when the checkout is detached.
    public let branch: String?

    public let isPrimary: Bool
    public let isDetached: Bool
    public let isLocked: Bool

    /// Whether HEAD names a commit yet. Everything compares against the empty tree when it does not.
    public let hasUnbornHead: Bool

    /// Set from the phone, and the only one of the three names a person chose deliberately.
    public let alias: String?

    /// Derived from the agent's own session transcript, best effort and never blocking.
    public let suggestedAlias: String?

    /// Resolved once on the server so both apps and every list agree on what this worktree is
    /// called: `alias`, else `suggestedAlias`, else the branch, else the directory.
    public let displayName: String

    public let directoryName: String
    public let isPinned: Bool
    public let stats: ChangeStats
    public let lastModified: Date

    /// Moves whenever anything in the worktree moves.
    public let revision: String

    public init(
        id: WorktreeID,
        projectId: ProjectID,
        projectName: String,
        branch: String?,
        isPrimary: Bool,
        isDetached: Bool,
        isLocked: Bool,
        hasUnbornHead: Bool,
        alias: String?,
        suggestedAlias: String?,
        displayName: String,
        directoryName: String,
        isPinned: Bool,
        stats: ChangeStats,
        lastModified: Date,
        revision: String
    ) {
        self.id = id
        self.projectId = projectId
        self.projectName = projectName
        self.branch = branch
        self.isPrimary = isPrimary
        self.isDetached = isDetached
        self.isLocked = isLocked
        self.hasUnbornHead = hasUnbornHead
        self.alias = alias
        self.suggestedAlias = suggestedAlias
        self.displayName = displayName
        self.directoryName = directoryName
        self.isPinned = isPinned
        self.stats = stats
        self.lastModified = lastModified
        self.revision = revision
    }
}
