import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// One file's whole diff: each hunk's band, then that hunk's lines.
///
/// **The gutter is sized once for the file and not once per hunk**, which is design §4's "width is
/// computed per file from its own maximum line number" taken literally. Per hunk, the numbers would
/// step in and out as the reader scrolled — a column that changes width mid-file is the same defect
/// as a title that changes while you scroll, and it is one the reader would blame on themselves.
///
/// **Whether a hunk can expand is asked of the hunks themselves**, which is what splicing into the
/// diff rather than into a structure beside it buys: a hunk that has grown carries its new bounds,
/// so the control disappears the moment the gap it opens is closed and cannot go on offering a
/// window that is empty.
public struct DiffFileContent: View {

    private let diff: FileDiff
    private let showsOldNumber: Bool
    private let onExpand: (ContextDirection, Int, FileID) -> Void

    /// The expansion reports which file it is in, because this view has the whole `FileDiff` and its
    /// caller would only be re-attaching an identifier it is already holding.
    public init(
        diff: FileDiff,
        showsOldNumber: Bool,
        onExpand: @escaping (ContextDirection, Int, FileID) -> Void
    ) {
        self.diff = diff
        self.showsOldNumber = showsOldNumber
        self.onExpand = onExpand
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(diff.hunks.enumerated()), id: \.element.index) { position, hunk in
                DiffHunkHeader(
                    hunk: hunk,
                    canExpandAbove: ContextExpansion.above(hunk, after: hunkBefore(position)) != nil,
                    canExpandBelow: ContextExpansion.below(
                        hunk,
                        before: hunkAfter(position),
                        endingAt: diff.newLineCount
                    ) != nil,
                    onExpandAbove: { onExpand(.above, hunk.index, diff.file.id) },
                    onExpandBelow: { onExpand(.below, hunk.index, diff.file.id) }
                )
                DiffFileLines(
                    lines: hunk.lines,
                    showsOldNumber: showsOldNumber,
                    highestOldNumber: highestOldNumber,
                    highestNewNumber: highestNewNumber
                )
            }
        }
        // **Twenty lines arriving is a layout change the reader pressed for, so it moves rather than
        // jumps.** Keyed on how many lines each hunk is drawing rather than on the whole diff: that
        // is exactly what an expansion changes, and the height of everything below the band is what
        // has to travel. A key of the whole `FileDiff` would also fire on a mark being set, which
        // moves nothing.
        .animation(.disclosure, value: diff.hunks.map(\.lines.count))
    }

    private func hunkBefore(_ position: Int) -> Hunk? {
        position > 0 ? diff.hunks[position - 1] : nil
    }

    private func hunkAfter(_ position: Int) -> Hunk? {
        position + 1 < diff.hunks.count ? diff.hunks[position + 1] : nil
    }

    private var highestOldNumber: Int {
        diff.hunks.flatMap(\.lines).compactMap(\.oldNumber).max() ?? 0
    }

    private var highestNewNumber: Int {
        diff.hunks.flatMap(\.lines).compactMap(\.newNumber).max() ?? 0
    }
}
