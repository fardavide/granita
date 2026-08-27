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

    /// §4's hit area. The band itself is shorter than this, so the control is what sets the row's
    /// height rather than the other way round.
    public static let controlSide: CGFloat = 44

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

    /// **The band grows to 44pt only where it carries a control**, so a hunk with nothing to expand
    /// is the same thin band it was before they arrived. The alternative — a hit area larger than
    /// the row it is drawn in — overlaps the code above and below it, and a tap that lands on a
    /// diff line and expands a hunk is worse than one that misses.
    public var body: some View {
        HStack(spacing: 0) {
            heading
                .padding(.leading, 12)
                .padding(.vertical, 4)
            Spacer(minLength: 8)
            controls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .frame(width: Self.controlSide, height: Self.controlSide)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
