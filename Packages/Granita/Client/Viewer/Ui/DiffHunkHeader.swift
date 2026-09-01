import SwiftUI

import CoreDiffDomain

/// The band between two hunks, carrying git's own section heading and the way into the lines it skipped.
///
/// Design §4: that string is the most useful free thing in the whole diff — it is usually the
/// enclosing function — and it is also the reason the band does not read as content. Proportional
/// rather than monospaced, secondary, on `quaternarySystemFill`: everything about it says *this is
/// not code*, which is what lets the eye skip it while scrolling and find it when lost.
///
/// **The expand controls are on the trailing edge, in a 44pt hit area**, which is §4 taken
/// literally. Not the leading edge: that is the gutter's column, and a glyph there reads as a line
/// number.
///
/// **Each one is absent when the gap it would open is empty.** A hunk at the top of a file has
/// nothing above it and a hunk running to the last line has nothing below, and a chevron over an
/// empty gap is the smallest possible lie — so `ContextExpansion` answers with a window or with
/// nothing, and nothing is what removes the control.
public struct DiffHunkHeader: View {

    /// **The band is 26pt now and the control no longer sets its height**, which is the review's
    /// fourth fault answered: a full-bleed grey slab taller than three rows of the code it stands
    /// for, over rows the same review calls cramped. "The chrome is loose and the content is
    /// cramped, which is backwards."
    public static let height: CGFloat = 26

    /// **The hit area is bought horizontally instead of vertically.** 44pt of width in a 26pt band,
    /// which is the same trade the file header's viewed toggle used to make for the same reason: a
    /// hit area taller than the row it is drawn in overlaps the code above and below it, and a tap
    /// that lands on a diff line and expands a hunk is worse than one that misses.
    ///
    /// It is a departure from the 44pt square, and it is deliberate — recorded in
    /// `.claude/docs/decisions.md` rather than left as a number that drifted.
    public static let controlWidth: CGFloat = 44

    private let hunk: Hunk
    private let canExpandAbove: Bool
    private let canExpandBelow: Bool
    private let onExpandAbove: () -> Void
    private let onExpandBelow: () -> Void

    public init(
        hunk: Hunk,
        canExpandAbove: Bool,
        canExpandBelow: Bool,
        onExpandAbove: @escaping () -> Void,
        onExpandBelow: @escaping () -> Void
    ) {
        self.hunk = hunk
        self.canExpandAbove = canExpandAbove
        self.canExpandBelow = canExpandBelow
        self.onExpandAbove = onExpandAbove
        self.onExpandBelow = onExpandBelow
    }

    /// **One height whether or not it carries a control**, which is what taking the control down to
    /// the band's own height buys: a hunk that can expand and one that cannot are now the same strip,
    /// so a file does not change rhythm down its length.
    public var body: some View {
        HStack(spacing: 0) {
            heading
                .padding(.leading, 12)
            Spacer(minLength: 8)
            controls
        }
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .leading)
        .background(.quaternary)
    }

    /// **A hunk with no heading still gets its band**, because the band's other job is structural:
    /// it says the diff jumped, and without it two hunks read as one run of lines whose numbers
    /// happen to skip. git omits the heading often — a change at the top of a file has nothing
    /// enclosing it — so this is the ordinary case rather than the odd one, and design §4 draws
    /// only the case where a heading exists.
    @ViewBuilder private var heading: some View {
        if let sectionHeading = hunk.sectionHeading {
            Text(verbatim: sectionHeading)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                // The heading is a fragment of a declaration, so its end is where the arguments are
                // and its start is the keyword. The start is what identifies it.
                .truncationMode(.tail)
        }
    }

    /// Two controls where there are two gaps, one where there is one, and none at the ends of a file
    /// that has neither.
    @ViewBuilder private var controls: some View {
        HStack(spacing: 0) {
            if canExpandAbove {
                control(
                    named: "chevron.up",
                    label: "Show the lines above this hunk",
                    action: onExpandAbove
                )
            }
            if canExpandBelow {
                control(
                    named: "chevron.down",
                    label: "Show the lines below this hunk",
                    action: onExpandBelow
                )
            }
        }
    }

    private func control(named symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
                .frame(width: Self.controlWidth, height: Self.height)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
