import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// A comment whose lines are no longer in the diff, under the header of the file they were in.
///
/// **Drawn rather than hidden, which is design §7.3's call 4.** The comment is still in the review
/// and still goes in the exported document, so hiding it would leave an invisible thing in a text the
/// reader is about to send — and a mark you cannot see is a mark you cannot delete.
///
/// **It cannot keep a rail**, because a rail sits beside rows and this one has none. So it becomes a
/// row of its own, in the one place that is still true about it: under its file's own header.
///
/// **Why a 44pt row is legal here, when the no-reflow rule forbids inserting height into a file.**
/// Staleness can only *become* true when the diff is re-read, and a re-read re-measures the document
/// from the top — it cannot land under a finger. Today the screen loads once from its `.task` and the
/// only other route in is a retry from the failure state, so the row can only appear across a
/// relaunch. **If a refresh is ever added, this row has to be re-argued**, and design §7.3 says so
/// itself.
public struct StaleCommentRow: View {

    /// Design §4's own figure for a row that is a control before it is a line of text.
    public static let height: CGFloat = 44

    private let count: Int
    private let line: Int
    private let onOpenReview: () -> Void

    public init(count: Int, line: Int, onOpenReview: @escaping () -> Void) {
        self.count = count
        self.line = line
        self.onOpenReview = onOpenReview
    }

    /// **It opens the review, which is the only thing a reader can still do with it.** The rows are
    /// gone, so there is nothing to scroll to and nothing to edit in place; what is left is the list,
    /// where the comment can be read and deleted. A row that only reported would be this project's
    /// dead control with a warning colour on it.
    public var body: some View {
        Button(action: onOpenReview) {
            HStack(spacing: DiffFileHeader.rowSpacing) {
                Image(systemName: "exclamationmark.bubble")
                    .font(.caption)
                    .frame(width: DiffFileHeader.chevronWidth)
                VStack(alignment: .leading, spacing: 1) {
                    Text(count == 1 ? "1 comment, no longer in this diff" : "\(count) comments, no longer in this diff")
                        .font(.footnote)
                        .lineLimit(1)
                    // What it *was* about, because the reader wrote it against something and the
                    // number is the only handle they have left on which something. Only for one:
                    // several lines in a row of this height would be a list, and the review is where
                    // the list is.
                    Text(count == 1 ? "was line \(line) · still in the review" : "still in the review")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 12)
            .padding(.trailing, DiffFileHeader.rowTrailingInset)
            .frame(height: Self.height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.diffCommentStale)
        // The card's own colour, so this sits on the file rather than on the page between files.
        .background(Color.diffCard)
        .accessibilityHint("Opens the review")
    }
}
