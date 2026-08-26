import SwiftUI

import CoreDiffDomain

/// One file's whole diff: each hunk's band, then that hunk's lines.
///
/// **The gutter is sized once for the file and not once per hunk**, which is design §4's "width is
/// computed per file from its own maximum line number" taken literally. Per hunk, the numbers would
/// step in and out as the reader scrolled — a column that changes width mid-file is the same defect
/// as a title that changes while you scroll, and it is one the reader would blame on themselves.
public struct DiffFileContent: View {

    private let hunks: [Hunk]
    private let showsOldNumber: Bool

    public init(hunks: [Hunk], showsOldNumber: Bool) {
        self.hunks = hunks
        self.showsOldNumber = showsOldNumber
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(hunks, id: \.index) { hunk in
                DiffHunkHeader(hunk: hunk)
                DiffFileLines(
                    lines: hunk.lines,
                    showsOldNumber: showsOldNumber,
                    highestOldNumber: highestOldNumber,
                    highestNewNumber: highestNewNumber
                )
            }
        }
    }

    private var highestOldNumber: Int {
        hunks.flatMap(\.lines).compactMap(\.oldNumber).max() ?? 0
    }

    private var highestNewNumber: Int {
        hunks.flatMap(\.lines).compactMap(\.newNumber).max() ?? 0
    }
}
