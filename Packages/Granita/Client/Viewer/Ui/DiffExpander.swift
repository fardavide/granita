import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// The lines the diff skipped, drawn as a tear across the file.
///
/// **A bar says a control is here; a tear says something is missing here.** Design §4 replaced the
/// grey band with this and the argument is that the second fact is the one a reader needs while
/// reading, and the one that survives being skimmed: a broken edge registers before any label does.
/// So the row is torn on the side the content is missing from, and that single rule draws all three
/// forms — torn above at the top of a file, torn below after the last change, torn both ways between
/// two hunks.
///
/// **There is no fourth form.** At the first line of a file there is nothing above to reveal, so the
/// row is absent rather than greyed out — §4: "a disabled control that can never be enabled is just a
/// label, and this one would sit at the top of every file you open." `DiffFileRow` is where that is
/// decided, before anything renders.
///
/// **What the row says depends on which way it is torn.** Upward it names the declaration the reader
/// is inside, because arriving in the middle of a file is what loses it; downward there is no such
/// thing to name, so it names its destination. Between two hunks the direction is ambiguous, so the
/// count moves into the label and each end gets its own 44pt control.
///
/// It reports which hunk and which way, and nothing about what that costs. The fetch is the model's.
public struct DiffExpander: View {

    /// A tap target before it is a row, which is what the one-way forms are: the whole 44pt is the
    /// control. The two-way form spends the same height on two of them.
    public static let height: CGFloat = 44

    private let gap: DiffGap
    private let gutterWidth: CGFloat
    private let onExpand: (ContextDirection, Int) -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// - Parameter gutterWidth: The file's own number column, so the glyph lands in the column the
    ///   line numbers are in rather than in a place of its own. Sized per file for the reason the
    ///   gutter is — see `DiffGutter`.
    public init(gap: DiffGap, gutterWidth: CGFloat, onExpand: @escaping (ContextDirection, Int) -> Void) {
        self.gap = gap
        self.gutterWidth = gutterWidth
        self.onExpand = onExpand
    }

    public var body: some View {
        row
            .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .leading)
            // **`ignoresSafeAreaEdges: []`, and the first recording is what said so.** A `ShapeStyle`
            // background ignores the safe area on every edge by default, so an expander at the top of
            // a file painted the status bar its own blue.
            .background(
                Color.accentColor.opacity(colorScheme == .dark ? 0.10 : 0.05),
                ignoresSafeAreaEdges: []
            )
            .overlay(alignment: .top) { edge }
            .overlay(alignment: .bottom) { edge }
            .overlay(alignment: .top) { tear(alignedTo: .top) }
            .overlay(alignment: .bottom) { tear(alignedTo: .bottom) }
    }

    @ViewBuilder private var row: some View {
        switch gap {
        case .aboveTheFirstHunk(let lineCount, let heading, let hunk):
            // The heading is git's own, and `nil` is the ordinary case rather than the odd one: it
            // omits the string whenever nothing encloses the change.
            oneWay(glyph: .upward, saying: heading, of: lineCount) { onExpand(.above, hunk) }
        case .afterTheLastHunk(let lineCount, let hunk):
            oneWay(glyph: .downward, saying: "remainder of file", of: lineCount) { onExpand(.below, hunk) }
        case .betweenHunks(let lineCount, let above, let below):
            betweenHunks(lineCount, above: above, below: below)
        }
    }

    /// **The whole row**, because there is only one thing it can do and 44pt of it is a better target
    /// than any glyph inside it. The glyph sits in the gutter's own column, which the first build
    /// refused on the grounds that a mark there reads as a line number — §4 overturned that when the
    /// mark stopped being a chevron: an arrow over three dashes reads as the lines that are missing,
    /// which is what the column is standing in for.
    private func oneWay(
        glyph: HiddenLines.Direction,
        saying label: String?,
        of lineCount: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                HiddenLines(direction: glyph)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.55, lineCap: .round, lineJoin: .round))
                    .frame(width: glyphWidth, height: HiddenLines.size.height)
                    // Ended where the figures end rather than where their column does, which is the
                    // arithmetic `DiffFileLines` draws a line number with. Aligned to the column's
                    // own edge instead, the glyph sat nine points to the right of every number in
                    // the file and stopped reading as one of them.
                    .frame(width: figureWidth, alignment: .trailing)
                    .padding(.trailing, DiffGutter.trailingSpace + DiffGutter.markerWidth + DiffGutter.markerTrailingSpace)
                text(label ?? "")
                Spacer(minLength: 8)
                count(lineCount)
                    .padding(.trailing, Self.countTrailingInset)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(saying: label, of: lineCount))
    }

    /// **Two targets, and the only form that has them.** Either end of the gap can be revealed and
    /// neither direction is the obvious one, so the count moves into the label and the trailing edge
    /// carries a control per direction. Up reveals the lines at the bottom of the gap, by extending
    /// the hunk below it upward; down reveals the top of the gap, by extending the hunk above it.
    private func betweenHunks(_ lineCount: Int, above: Int, below: Int) -> some View {
        HStack(spacing: 0) {
            // No glyph: the tear is on both edges, so there is no one direction to point in, and
            // the two controls at the other end say it instead.
            Color.clear
                .frame(width: codeOrigin, height: 1)
            text(lineCount == 1 ? "1 line not shown" : "\(lineCount) lines not shown")
            Spacer(minLength: 8)
            control(named: "chevron.up", label: "Show the lines below this gap") { onExpand(.above, below) }
            Rectangle()
                .frame(width: 1 / 3, height: Self.dividerHeight)
                .foregroundStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.16))
            control(named: "chevron.down", label: "Show the lines above this gap") { onExpand(.below, above) }
        }
    }

    /// As far as the figures reach, which is the column minus the space it keeps before the code.
    private var figureWidth: CGFloat {
        max(0, gutterWidth - DiffGutter.trailingSpace)
    }

    /// Where the file's own code starts, so a row's label begins on the same column the lines above
    /// and below it do.
    private var codeOrigin: CGFloat {
        gutterWidth + DiffGutter.markerWidth + DiffGutter.markerTrailingSpace
    }

    /// **The glyph shrinks rather than overflowing**, which a file of under ten lines is what asks
    /// for: one figure buys about eleven points of column and the drawing wants thirteen, so at its
    /// stated size it hung off the leading edge of the row. Scaled, it stays inside a column it can
    /// no longer fill, and the label beside it stays where the code is — which is the alignment worth
    /// protecting.
    ///
    /// The gutter's own leading inset comes off it too, or the smallest column pins the drawing
    /// against the bezel — which the numbers never are, because a single figure does not fill their
    /// column either.
    private var glyphWidth: CGFloat {
        min(HiddenLines.size.width, max(0, figureWidth - DiffGutter.leadingInset))
    }

    /// §4's own width for the two controls, and the one number in this file that is a hit area rather
    /// than a drawing.
    static let controlWidth: CGFloat = 44

    /// Shorter than the row, so the rule between the two controls reads as a separator rather than
    /// as a second tear.
    static let dividerHeight: CGFloat = 20

    /// Between the count and the trailing edge. Wider than the row's other gaps because nothing sits
    /// outside it — the one-way forms have no control on that edge.
    static let countTrailingInset: CGFloat = 14

    private func control(
        named symbol: String,
        label: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: Self.controlWidth, height: Self.height)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Mono, because it is a fragment of the file rather than a sentence about it — and because the
    /// row it replaces was.
    private func text(_ label: String) -> some View {
        Text(verbatim: label)
            .font(.caption2.monospaced())
            .foregroundStyle(labelColour)
            .lineLimit(1)
            // The heading is a fragment of a declaration, so its end is where the arguments are and
            // its start is the keyword. The start is what identifies it.
            .truncationMode(.tail)
    }

    private func count(_ lineCount: Int) -> some View {
        Text(lineCount == 1 ? "1 line" : "\(lineCount, format: .number) lines")
            .font(.caption2.monospaced())
            .monospacedDigit()
            .foregroundStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.85 : 0.6))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func accessibilityLabel(saying label: String?, of lineCount: Int) -> Text {
        let lines = lineCount == 1 ? Text("1 hidden line") : Text("\(lineCount, format: .number) hidden lines")
        guard let label, label.isEmpty == false else { return lines }
        return Text("\(lines), \(label)")
    }

    /// **Darker than the accent in light and lighter in dark**, which is legibility rather than
    /// decoration: 10pt type on a 5% wash of the same hue is at the edge of readable, and the review
    /// picked a value either side of it. The two literals are this file's only ones, for the reason
    /// `fileStatusAmber` is the palette's: the system has no semantic colour for *accent, but
    /// readable as text*.
    private var labelColour: Color {
        colorScheme == .dark
            ? Color(red: 0.549, green: 0.761, blue: 1)
            : Color(red: 0.039, green: 0.365, blue: 0.761)
    }

    private var edge: some View {
        Rectangle()
            .frame(height: 1 / 3)
            .foregroundStyle(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.16))
    }

    /// The tear itself, and nothing on the edge the content is not missing from.
    @ViewBuilder private func tear(alignedTo edge: VerticalAlignment) -> some View {
        if isTorn(at: edge) {
            TornEdge(bitesFrom: edge)
                .fill(
                    Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14),
                    style: FillStyle(eoFill: true)
                )
                .frame(height: TornEdge.depth)
                // **Clipped, and the first recording is what said so.** An even-odd fill leaves the
                // half of each bite that falls *outside* the strip filled, so uncut the row came out
                // as a string of bubbles sitting on the edge rather than as a tear taken out of it.
                .clipped()
        }
    }

    private func isTorn(at edge: VerticalAlignment) -> Bool {
        switch gap {
        case .aboveTheFirstHunk: edge == .top
        case .afterTheLastHunk: edge == .bottom
        case .betweenHunks: true
        }
    }
}
