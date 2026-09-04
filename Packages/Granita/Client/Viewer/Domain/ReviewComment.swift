import CoreDiffDomain

/// One drawn row of a file's diff, addressed by the numbers it carries.
///
/// **This is an address, not a position.** Hunk expansion splices twenty lines into the middle of a
/// file and re-opening the screen replaces every hunk, so an offset into the drawn rows stops
/// pointing at the row the reader chose. Old numbers rise monotonically down the old side and new
/// numbers down the new one, which makes the pair unique within a file and leaves it unmoved by
/// either — a deletion is `(11, nil)` and stays `(11, nil)` however much context arrives above it.
///
/// **A row where neither is present cannot be addressed**, and there is exactly one such row:
/// `\ No newline at end of file`. It carries no number on either side, so two of them in one file —
/// which happens whenever a trailing newline is added, one marker behind the deletion and one behind
/// the addition — are indistinguishable. It costs nothing, because design §4's gutter draws no
/// figure for it either, and there is no number to tap. A selection still *spans* it and the quote
/// carries it verbatim.
///
/// **A conflict marker is not one of these**, which is worth saying because it looks like it should
/// be. It reaches the parser behind an ordinary `+` or space and is re-tagged by its text alone, so
/// it keeps whichever numbers that prefix gave it — and the rows a reader most wants to point at
/// stay addressable.
public struct DiffLinePosition: Hashable, Codable, Sendable {

    public let oldNumber: Int?
    public let newNumber: Int?

    public init(oldNumber: Int?, newNumber: Int?) {
        self.oldNumber = oldNumber
        self.newNumber = newNumber
    }

    /// Where this row is, or nothing at all when it is one of the rows that is nowhere.
    public static func of(_ line: DiffLine) -> DiffLinePosition? {
        guard line.oldNumber != nil || line.newNumber != nil else { return nil }
        return DiffLinePosition(oldNumber: line.oldNumber, newNumber: line.newNumber)
    }
}

/// The rows one comment is attached to, as the two ends of a run in the order the diff is drawn.
///
/// **The anchor is the comment's identity**, which is what makes a second tap on a commented row an
/// edit rather than a duplicate. A review is a note left for an agent and not a thread, so nothing
/// here needs two comments to sit on one span — and an identity that is a generated value would have
/// to be stored, matched and kept unique for no gain.
public struct CommentAnchor: Hashable, Codable, Sendable {

    public let file: FileID
    public let first: DiffLinePosition
    public let last: DiffLinePosition

    public init(file: FileID, first: DiffLinePosition, last: DiffLinePosition) {
        self.file = file
        self.first = first
        self.last = last
    }
}

/// How a comment's rows are named to the agent: which side of the comparison, and the span there.
///
/// **The new side wherever it exists at all.** The agent is about to open the working copy, so
/// "line 12" has to mean the line it would find. A run that is nothing but deletions has no
/// new-side existence, and reporting one for it would send the agent to whatever now sits at those
/// numbers — so that run is named on the old side and the document says which.
public struct CommentedLines: Hashable, Codable, Sendable {

    public let side: DiffSide
    public let first: Int
    public let last: Int

    public init(side: DiffSide, first: Int, last: Int) {
        self.side = side
        self.first = first
        self.last = last
    }

    /// Which side these rows are reported on, and the span they cover there.
    ///
    /// Absent when no row carries a number on either side, which is a run of nothing but no-newline
    /// markers. Unreachable through a selection, whose ends are addressable by construction, and
    /// answered here rather than assumed away.
    public static func of(_ rows: [DiffLine]) -> CommentedLines? {
        let new = rows.compactMap(\.newNumber)
        if let first = new.min(), let last = new.max() {
            return CommentedLines(side: .new, first: first, last: last)
        }
        let old = rows.compactMap(\.oldNumber)
        guard let first = old.min(), let last = old.max() else { return nil }
        return CommentedLines(side: .old, first: first, last: last)
    }
}

/// One thing the reader had to say about one run of lines.
///
/// **Everything the document needs is snapshotted here rather than resolved when it is exported.**
/// The path, the span and the excerpt are taken at the moment the comment is written, because the
/// agent this is written for is about to change exactly those lines — a quote re-derived later would
/// show its reply rather than the reader's question, and a comment on a file the agent has since
/// reverted would have nothing to quote at all.
public struct ReviewComment: Hashable, Codable, Sendable, Identifiable {

    public let anchor: CommentAnchor

    /// Repo-relative, as the change set reported it. Carried rather than looked up so a comment
    /// survives its file leaving the change set.
    public let path: String

    public let lines: CommentedLines

    /// The rows as they were drawn, each behind the marker git would have written for it.
    public let quotedLines: [String]

    public let text: String

    public init(
        anchor: CommentAnchor,
        path: String,
        lines: CommentedLines,
        quotedLines: [String],
        text: String
    ) {
        self.anchor = anchor
        self.path = path
        self.lines = lines
        self.quotedLines = quotedLines
        self.text = text
    }

    public var id: CommentAnchor { anchor }
}
