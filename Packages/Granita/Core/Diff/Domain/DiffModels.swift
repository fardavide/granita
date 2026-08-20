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
