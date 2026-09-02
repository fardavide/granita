import CoreDiffDomain

/// A run of lines the diff is not drawing, and which way a reader can open it.
///
/// **Where the gap sits is the whole of the design, so it is the shape of the type.** Design §4's
/// expander is torn on the side the content is missing from, and that one rule decides everything
/// else about the row: which glyph it carries, what it can say, and how many controls it needs.
/// Three cases, and a fourth is unrepresentable rather than merely unused — a gap with content
/// missing on neither side is not a gap.
///
/// The hunk numbers are `Hunk.index`, which is what the expansion route is keyed by.
public enum DiffGap: Hashable, Sendable {

    /// Missing above the first hunk: the top of the file, which the diff skipped into.
    ///
    /// Opened upward, from the hunk below it. It carries git's own heading for that hunk because
    /// that is what a reader has lost by arriving in the middle of a file — design §4: "upward, it
    /// names the declaration you are inside".
    case aboveTheFirstHunk(lineCount: Int, heading: String?, hunk: Int)

    /// Missing between two hunks, so either end can be revealed and neither direction is the
    /// obvious one. The only gap with two controls.
    case betweenHunks(lineCount: Int, above: Int, below: Int)

    /// Missing after the last hunk: the rest of the file.
    ///
    /// Opened downward, from the hunk above it. There is no declaration to name below a change, so
    /// §4 has this one name its destination instead.
    case afterTheLastHunk(lineCount: Int, hunk: Int)

    /// How many lines are behind it, which every form of the row prints.
    public var lineCount: Int {
        switch self {
        case .aboveTheFirstHunk(let lineCount, _, _): lineCount
        case .betweenHunks(let lineCount, _, _): lineCount
        case .afterTheLastHunk(let lineCount, _): lineCount
        }
    }
}

/// One file's diff in the order the scroll draws it: its hunks, and the gaps between them.
///
/// **The gaps are rows rather than decorations on a hunk**, which is design §4's expander taken
/// literally and is a change from the first build. A band drawn *per hunk* carrying both an up and a
/// down control stands for two different gaps at once — the one before the hunk and the one after it
/// — so a reader pressing either has to work out which stretch of file they just asked for. One row
/// per gap cannot be ambiguous: it is torn where the lines are missing, and its controls open the
/// thing it is drawn across.
public enum DiffFileRow: Hashable, Sendable, Identifiable {

    case gap(DiffGap)
    case hunk(Hunk)

    /// Distinct across both cases, because a `ForEach` draws one row per identity and a gap and the
    /// hunk below it would otherwise collide on the same number.
    public var id: DiffFileRowID {
        switch self {
        case .gap(let gap):
            switch gap {
            case .aboveTheFirstHunk(_, _, let hunk): .gapAbove(hunk)
            case .betweenHunks(_, _, let below): .gapAbove(below)
            case .afterTheLastHunk(_, let hunk): .gapBelow(hunk)
            }
        case .hunk(let hunk): .hunk(hunk.index)
        }
    }

    /// A file's hunks with a gap row wherever the diff skipped something.
    ///
    /// **Nothing is drawn across an empty gap**, which is design §4's fourth state and the reason it
    /// says there is none: at the first line of a file there is nothing above to reveal, so the row
    /// is absent rather than disabled. A disabled control that can never be enabled is a label, and
    /// this one would sit at the top of most files.
    ///
    /// The bounds come from `ContextExpansion`, which is the same arithmetic the press itself uses —
    /// so a row that says how many lines are missing and the window that fetches them cannot
    /// disagree.
    public static func rows(of diff: FileDiff) -> [DiffFileRow] {
        var rows: [DiffFileRow] = []
        for (position, hunk) in diff.hunks.enumerated() {
            let previous = position > 0 ? diff.hunks[position - 1] : nil
            if let gap = ContextExpansion.gapAbove(hunk, after: previous) {
                rows.append(.gap(
                    previous.map { .betweenHunks(lineCount: gap.count, above: $0.index, below: hunk.index) }
                        ?? .aboveTheFirstHunk(lineCount: gap.count, heading: hunk.sectionHeading, hunk: hunk.index)
                ))
            }
            rows.append(.hunk(hunk))
        }
        // **Read from the file's length rather than from the last hunk**, which is the one bound
        // this client cannot check: see `decisions.md` on what the Mac reports here.
        if let last = diff.hunks.last,
           let gap = ContextExpansion.gapBelow(last, before: nil, endingAt: diff.newLineCount) {
            rows.append(.gap(.afterTheLastHunk(lineCount: gap.count, hunk: last.index)))
        }
        return rows
    }
}

/// What tells one drawn row from another.
public enum DiffFileRowID: Hashable, Sendable {
    case gapAbove(Int)
    case gapBelow(Int)
    case hunk(Int)
}
