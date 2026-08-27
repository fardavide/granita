import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// A file the scroll is not drawing, and the reason it is not.
///
/// **44pt and four things** — design §4: status letter, head-truncated path, stats, and the reason,
/// which is the one the specification does not name and the one the section argues hardest for.
/// Without it the reader opens a file to learn there was nothing in it, which is the exact cost
/// collapsing was supposed to save; with it, a run of six bars is readable at a glance and three of
/// the six never need opening.
///
/// **A binary file and a rename that changed nothing get no chevron at all**, and the whole row
/// stops being a button with it. There is nothing behind them, and a disclosure control that
/// discloses nothing is the smallest possible lie.
///
/// It is not the file header wearing a different hat. The header is 28pt and pinned, and this is a
/// 44pt row that scrolls with everything else — a bar is content, and the reader's finger has a
/// whole row to land on rather than the 28pt strip the no-reflow rule holds the header to.
public struct DiffCollapsedFileBar: View {

    /// Design §4's own measurement, and the reason it is stated: this is a tap target before it is
    /// a row, and 44pt is what makes it one.
    public static let height: CGFloat = 44

    private let file: FileChange
    private let collapse: FileCollapse
    private let onSetOpen: (Bool, FileID) -> Void

    /// It reports which file it is about, for the reason the header does: the bar has the file, and
    /// a caller re-attaching its identifier is a wrapper per bar per frame.
    public init(file: FileChange, collapse: FileCollapse, onSetOpen: @escaping (Bool, FileID) -> Void) {
        self.file = file
        self.collapse = collapse
        self.onSetOpen = onSetOpen
    }

    public var body: some View {
        if collapse.isCollapsible {
            Button { onSetOpen(true, file.id) } label: { row }
                .buttonStyle(.plain)
                .accessibilityHint("Opens this file's diff")
        } else {
            row
        }
    }

    private var row: some View {
        HStack(alignment: .center, spacing: 8) {
            chevron
            FileStatusLetter(status: file.status)
            VStack(alignment: .leading, spacing: 1) {
                path
                reason
            }
            Spacer(minLength: 8)
            stats
            viewedMark
        }
        .font(.footnote)
        .padding(.horizontal, 12)
        .frame(height: Self.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        // **A rule rather than a `Divider`, and the baseline is what said so.** `Divider` takes its
        // axis from the layout it is in, and inside a `Button`'s label it read this row's `HStack`
        // and drew itself *vertically* — a stray line down the middle of two bars and no rule under
        // them, while the two bars that are not buttons got the horizontal one. Stating the shape
        // is the same answer this repository reached about the list margin and the scroll position.
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1 / 3)
                .foregroundStyle(.separator)
        }
    }

    /// **Absent, not dimmed, when there is nothing behind the bar.** The frame draws it faded for
    /// those two rows; a faded chevron is still a chevron, and this project's one unbreakable rule
    /// is that a control a reader can see does something. The row keeps its leading inset so the
    /// letters stay in one column down the screen.
    @ViewBuilder private var chevron: some View {
        if collapse.isCollapsible {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            // What the glyph takes, so a row without one puts its letter in the same column.
            Color.clear.frame(width: 8, height: 1)
        }
    }

    /// Head-truncated, because a path's tail is the filename and the filename is what identifies it.
    private var path: some View {
        Text(verbatim: file.path)
            .lineLimit(1)
            .truncationMode(.head)
            // A file already read is a file the reader is done with, and the selector's row says the
            // same thing the same way.
            .foregroundStyle(collapse.reason == .viewed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
    }

    /// The line design §4 added to the specification, and `nil` where there is nothing true to say.
    ///
    /// **A file the reader shut by hand has no reason**, so the bar is one line rather than two.
    /// The four sentences below are the four the app decided on its own; telling someone they shut
    /// a file they have just shut is a line that says nothing.
    /// **"viewed" rather than design §4's "viewed 4 minutes ago"**, and that is a fact about the
    /// wire rather than a shortened sentence: the Mac stores a mark as the content hash it was set
    /// against and keeps no time beside it, so the elapsed reading is a number this phone would have
    /// to invent. Same call as §3's truncation footer, and it is in `decisions.md`.
    @ViewBuilder private var reason: some View {
        if let reasonText {
            reasonText
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var reasonText: Text? {
        switch collapse.reason {
        case .viewed:
            Text("viewed")
        case .tooLong(let lines):
            // Grouped, and the separator is the reader's locale rather than ours. The snapshot
            // helper pins one so a baseline asserts a layout rather than a machine.
            Text("\(lines, format: .number) lines · Load diff")
        case .binary:
            Text("binary · no diff to show")
        case .renamedWithNoContentChange(let oldName):
            Text("renamed from \(oldName) · no content change")
        case nil:
            nil
        }
    }

    private var stats: some View {
        changeStatsText(file.stats)
            .monospacedDigit()
    }

    /// **It reports and does not act**, which is §3's call about a row with a jump on it and the
    /// same one applies here: the whole bar is one tap target, so a second one inside it generates
    /// mis-taps. The writer is the circle in the file header, one tap away.
    @ViewBuilder private var viewedMark: some View {
        if file.isViewed {
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Viewed")
        }
    }
}
