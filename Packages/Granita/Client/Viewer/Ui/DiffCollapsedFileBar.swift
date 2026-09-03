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
    private let commentCount: Int
    private let onSetOpen: (Bool, FileID) -> Void

    /// It reports which file it is about, for the reason the header does: the bar has the file, and
    /// a caller re-attaching its identifier is a wrapper per bar per frame.
    ///
    /// **This is the row the chip exists for.** A shut file has no rows, so it can carry no rail —
    /// design §7.3's whole argument for having a second mark at all.
    public init(
        file: FileChange,
        collapse: FileCollapse,
        commentCount: Int = 0,
        onSetOpen: @escaping (Bool, FileID) -> Void
    ) {
        self.file = file
        self.collapse = collapse
        self.commentCount = commentCount
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
        HStack(alignment: .center, spacing: DiffFileHeader.rowSpacing) {
            chevron
            FileStatusBar(status: file.status)
            VStack(alignment: .leading, spacing: 1) {
                name
                secondLine
            }
            Spacer(minLength: 8)
            CommentCountChip(count: commentCount)
            stats
            viewedMark
        }
        // **Reviewed means quiet**, the same 45% the open header uses. A shut, read file is the row
        // a reader scans *past*, and an eleven-file pass leaves a visible trail of them.
        .opacity(file.isViewed ? DiffFileHeader.viewedOpacity : 1)
        .font(.footnote)
        .padding(.leading, 12)
        // The four points design §4's frame puts after the 44pt slot, so nothing in this row ends
        // against the bezel.
        .padding(.trailing, DiffFileHeader.rowTrailingInset)
        .frame(height: Self.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Opaque, and outside the dim above it: this sits in the section header's slot and floats
        // over the page the files are separated by, so a bar left transparent would show the gap
        // through itself — and a background inside the `.opacity` would fade the card rather than
        // what the card says.
        .background(Color.diffCard)
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
    ///
    /// **The slot is the header's, and it is the header's number rather than this file's**, because
    /// the two rows swap places when a file shuts: `chevron.right` is narrower than the
    /// `chevron.down` above it, so a bar that let its glyph size the slot put every row below the
    /// column the open file was drawing.
    @ViewBuilder private var chevron: some View {
        if collapse.isCollapsible {
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: DiffFileHeader.chevronWidth)
        } else {
            // What the glyph takes, so a row without one puts its name in the same column.
            Color.clear.frame(width: DiffFileHeader.chevronWidth, height: 1)
        }
    }

    /// The filename alone and never truncated, which is the open header's treatment brought down to
    /// the bar so a file does not change what it calls itself when it shuts.
    private var name: some View {
        Text(verbatim: DiffFilePath.name(of: file.path))
            .fontWeight(.semibold)
            .lineLimit(1)
            // A file already read is a file the reader is done with, and the selector's row says the
            // same thing the same way.
            .foregroundStyle(collapse.reason == .viewed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
    }

    /// **The reason when there is one, and the directory when there is not.**
    ///
    /// The reason is the more useful of the two — "1,558 lines · Load diff" is why the file is shut
    /// and what pressing it will do — so it wins the slot wherever it exists. A file the reader shut
    /// by hand has no reason, and rather than leaving that bar a single line the slot falls back to
    /// the place the file lives, which is what the open header shows there.
    @ViewBuilder private var secondLine: some View {
        if reasonText != nil {
            reason
        } else {
            directory
        }
    }

    /// Middle-truncated for the same reason the open header's is: both ends of a directory carry
    /// information, and head-truncation deletes the module.
    @ViewBuilder private var directory: some View {
        let place = DiffFilePath.directory(of: file.path)
        if place.isEmpty == false {
            Text(verbatim: place)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
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

    /// **It keeps its width and the line beside it gives way**, which is the opposite of §3's drop
    /// order and is right here for a reason that screen does not have: this row's trailing 46pt is a
    /// slot rather than a margin, so a count allowed to compress does not shorten — it wraps at the
    /// space between the two figures, and a 44pt row with a two-line label clips the second one under
    /// the bezel. `+1,240 −318` was doing exactly that beside a long *Load diff* line.
    private var stats: some View {
        changeStatsText(file.stats)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }

    /// **It reports and does not act**, which is §3's call about a row with a jump on it and the
    /// same one applies here: the whole bar is one tap target, so a second one inside it generates
    /// mis-taps. The writer is the circle in the file header, one tap away.
    ///
    /// **The slot is always there and is the header's own width**, empty or not. Without it a shut
    /// file's stats sat 46pt further right than an open file's, so the one column a reader scans down
    /// a change set stepped in and out at every boundary — visible in the baseline as soon as the
    /// header grew its 44pt target.
    ///
    /// **The glyph is drawn clear rather than left out, which is what makes that true.** A `Group`
    /// wrapping an absent `if` is an `EmptyView`, and a frame around one reserves nothing: the slot
    /// was there in the source and never in the layout, so an unread file's counts ran under the
    /// right bezel — `+1,240 −318` with its last figure cut off, on the row that most needed
    /// reading. §3's own row already says it this way, and now both do.
    private var viewedMark: some View {
        Image(systemName: "checkmark")
            .font(.footnote)
            .foregroundStyle(file.isViewed ? AnyShapeStyle(Color.green) : AnyShapeStyle(.clear))
            .frame(width: DiffFileHeader.height)
            .accessibilityLabel(file.isViewed ? "Viewed" : "Not viewed")
    }
}
