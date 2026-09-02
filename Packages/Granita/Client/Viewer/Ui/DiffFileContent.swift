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
    private let onExpand: (ContextDirection, Int, FileID) -> Void

    /// The expansion reports which file it is in, because this view has the whole `FileDiff` and its
    /// caller would only be re-attaching an identifier it is already holding.
    public init(
        diff: FileDiff,
        pointSize: CGFloat,
        onExpand: @escaping (ContextDirection, Int, FileID) -> Void
    ) {
        self.diff = diff
        self.pointSize = pointSize
        self.onExpand = onExpand
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
                        pointSize: pointSize
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
