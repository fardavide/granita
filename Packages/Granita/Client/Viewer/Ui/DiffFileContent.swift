import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// One file's whole diff: its hunks, and a torn expander wherever the diff skipped something.
///
/// **The gutter is sized once for the file and not once per hunk**, which is design §4's "width is
/// computed per file from its own maximum line number" taken literally. Per hunk, the numbers would
/// step in and out as the reader scrolled — a column that changes width mid-file is the same defect
/// as a title that changes while you scroll, and it is one the reader would blame on themselves.
///
/// **Which rows exist is decided in `Domain` and not here**, and that is what changed when §4 made
/// the band an expander: a row now stands for one gap rather than for one hunk, so where it sits
/// decides how it is torn, what it may say, and how many controls it needs. That is a rule with three
/// outcomes and a fourth that must not be drawn, which is a pure function's job rather than a view's.
///
/// **Whether a gap exists is asked of the hunks themselves**, which is what splicing into the diff
/// rather than into a structure beside it buys: a hunk that has grown carries its new bounds, so the
/// row disappears the moment the gap it was drawn across is closed.
public struct DiffFileContent: View {

    private let diff: FileDiff
    private let pointSize: CGFloat

    /// Every comment the reader has written, not only this file's.
    ///
    /// **Filtered here rather than by the caller**, for the reason the expansion callback is shaped
    /// the way it is: this view holds the whole `FileDiff`, so it is the one place that can answer
    /// which of them belong to it without an identifier being re-attached on the way in.
    private let comments: [ReviewComment]

    /// The run being picked out, wherever it is. `CommentRail` drops it if it is not this file's.
    private let pending: PendingComment?

    /// This file's lexed code, which every hunk of it draws from. One value for the file rather than
    /// one per hunk, because `SPEC.md` §10 lexes a file per side and never a hunk.
    private let highlighted: HighlightedFile

    /// Whether the gutter takes gestures. False while a sheet is up — see `DiffFileLines`.
    private let acceptsTargeting: Bool

    private let onExpand: (ContextDirection, Int, FileID) -> Void
    private let onTapGutter: (DiffLinePosition, FileID) -> Void
    private let onLongPressGutter: (DiffLinePosition, FileID) -> Void

    /// The expansion and the two gutter gestures all report which file they are in, because this view
    /// has the whole `FileDiff` and its caller would only be re-attaching an identifier it is already
    /// holding.
    public init(
        diff: FileDiff,
        pointSize: CGFloat,
        comments: [ReviewComment] = [],
        pending: PendingComment? = nil,
        highlighted: HighlightedFile = .none,
        acceptsTargeting: Bool = true,
        onExpand: @escaping (ContextDirection, Int, FileID) -> Void,
        onTapGutter: @escaping (DiffLinePosition, FileID) -> Void = { _, _ in },
        onLongPressGutter: @escaping (DiffLinePosition, FileID) -> Void = { _, _ in }
    ) {
        self.diff = diff
        self.pointSize = pointSize
        self.comments = comments
        self.pending = pending
        self.highlighted = highlighted
        self.acceptsTargeting = acceptsTargeting
        self.onExpand = onExpand
        self.onTapGutter = onTapGutter
        self.onLongPressGutter = onLongPressGutter
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(DiffFileRow.rows(of: diff)) { row in
                switch row {
                case .gap(let gap):
                    DiffExpander(gap: gap, gutterWidth: gutterWidth) { direction, hunk in
                        onExpand(direction, hunk, diff.file.id)
                    }
                case .hunk(let hunk):
                    DiffFileLines(
                        lines: hunk.lines,
                        highestNumber: highestNumber,
                        pointSize: pointSize,
                        // **Clipped to this hunk, which is what makes a rail across a hunk boundary
                        // possible at all.** A file is several views with torn rows between them, so
                        // there is no coordinate space a single rail could span.
                        runs: CommentRail.runs(of: hunk, in: diff, comments: comments, pending: pending),
                        // Whole rather than clipped to this hunk, unlike the rails: a highlighted
                        // line is filed under the number the gutter draws, so a hunk takes what it
                        // needs by asking rather than by being handed a slice.
                        highlighted: highlighted,
                        acceptsTargeting: acceptsTargeting,
                        onTap: { onTapGutter($0, diff.file.id) },
                        onLongPress: { onLongPressGutter($0, diff.file.id) }
                    )
                }
            }
        }
        // **Twenty lines arriving is a layout change the reader pressed for, so it moves rather than
        // jumps.** Keyed on how many lines each hunk is drawing rather than on the whole diff: that
        // is exactly what an expansion changes, and the height of everything below the band is what
        // has to travel. A key of the whole `FileDiff` would also fire on a mark being set, which
        // moves nothing.
        .animation(.disclosure, value: diff.hunks.map(\.lines.count))
    }

    /// The column the expander puts its glyph in, so an arrow standing for hidden lines lands where
    /// the numbers of the lines around it are.
    private var gutterWidth: CGFloat {
        DiffGutter.columnWidth(forHighestLineNumber: highestNumber, atPointSize: pointSize)
    }

    /// **The larger of the two sides, because one column now carries both.** A file whose old side
    /// runs past its new one — a deletion of a hundred lines from the end — would otherwise size its
    /// gutter on the new maximum and then draw four-figure old numbers into a three-figure column.
    private var highestNumber: Int {
        let lines = diff.hunks.flatMap(\.lines)
        let highestOld = lines.compactMap(\.oldNumber).max() ?? 0
        let highestNew = lines.compactMap(\.newNumber).max() ?? 0
        return max(highestOld, highestNew)
    }
}
