import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// One file's diff lines with wrap off: the numbers pinned and the code scrolling under them.
///
/// **The two halves are separate view trees, and that is the shape rather than an implementation
/// detail.** `SPEC.md` §10 says long lines scroll horizontally within the file *with the gutter
/// pinned*, and a gutter inside the row is inside whatever scrolls the row — the first attempt put
/// both in one view and the baseline came back with the numbers pushed off the leading edge, because
/// a row wider than its container is centred in it. So the numbers are a fixed column outside the
/// scroll, the code is a stack inside it, and the price is that two stacks have to agree on every
/// row's height. That height is therefore stated once, below, rather than left to two text engines
/// to arrive at independently. See `.claude/docs/decisions.md`.
///
/// **The tints are drawn behind both halves rather than on either.** A row's colour says which side
/// of the comparison the line is on, which is a fact about the row and not about the text — so it
/// belongs outside the scroll, where it reaches the trailing edge and stays put while the code moves.
public struct DiffFileLines: View {

    /// 11pt, and every measurement in design §4 is taken at it: it is what makes 51 characters fit
    /// at 390pt with one gutter column. Whether it is readable at arm's length is the one thing a
    /// drawing could not judge and a device has to answer, which is why it is a named constant
    /// rather than a literal in four places.
    public static let codePointSize: CGFloat = 11

    /// §4's inset between the last character of code and the trailing edge.
    public static let codeTrailingInset: CGFloat = 12

    private let lines: [DiffLine]
    private let showsOldNumber: Bool

    @Environment(\.colorScheme) private var colorScheme

    public init(lines: [DiffLine], showsOldNumber: Bool) {
        self.lines = lines
        self.showsOldNumber = showsOldNumber
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            tints
            columns
        }
        .font(.system(size: Self.codePointSize, design: .monospaced))
    }

    /// A strip per row, full width, behind everything. Outside the scroll on purpose: a tint that
    /// slid away with the code would stop saying which side the line is on halfway through a long
    /// one.
    private var tints: some View {
        VStack(spacing: 0) {
            ForEach(numbered, id: \.offset) { _, line in
                tint(of: line)
                    .frame(maxWidth: .infinity)
                    .frame(height: rowHeight)
            }
        }
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: 0) {
            numbers
            code
        }
    }

    private var numbers: some View {
        VStack(spacing: 0) {
            ForEach(numbered, id: \.offset) { _, line in
                HStack(spacing: 0) {
                    if showsOldNumber {
                        figure(line.oldNumber, inColumnOf: highestOldNumber)
                    }
                    figure(line.newNumber, inColumnOf: highestNewNumber)
                }
                .frame(height: rowHeight)
            }
        }
    }

    /// One scroll for the whole file rather than one per line, which is what keeps the lines
    /// aligned with each other while they move.
    private var code: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(numbered, id: \.offset) { _, line in
                    segmented(line)
                        .lineLimit(1)
                        .frame(height: rowHeight, alignment: .leading)
                }
            }
            .padding(.trailing, Self.codeTrailingInset)
        }
        // **Height stated, not inherited.** A `ScrollView` is greedy on both axes whatever its
        // scroll axis is, so left alone this one fills the screen — which is invisible in a
        // full-screen baseline and unbounded inside the lazy stack this file will be a section of.
        // The same arithmetic the tints behind it use, so the two trees cannot come out different
        // heights.
        .frame(height: rowHeight * CGFloat(lines.count))
    }

    /// Blank on the side a line does not exist on — a deletion has no new number — and the row tint
    /// is what says which side that is, so nothing has to be written in the gap.
    private func figure(_ value: Int?, inColumnOf highest: Int) -> some View {
        Text(value.map(String.init) ?? "")
            .foregroundStyle(.tertiary)
            .monospacedDigit()
            .frame(
                width: DiffGutter.columnWidth(forHighestLineNumber: highest, atPointSize: Self.codePointSize)
                    - DiffGutter.trailingSpace,
                alignment: .trailing
            )
            .padding(.trailing, DiffGutter.trailingSpace)
    }

    /// The changed run at full strength and everything else at `.secondary`, in **both**
    /// appearances.
    ///
    /// Design §4: "stronger" is a ratio rather than a colour, and two nested backgrounds is the
    /// premise that does not survive dark mode — a 10% row tint under a 28% segment is a layer in
    /// light, and against black the row already needs 16% to be visible at all, which leaves no
    /// headroom above it. So the emphasis inverts and the eye finds the bright text rather than the
    /// darker box. The frames use it in all three palettes, and it is the only treatment that
    /// survives the colourblind one, where orange on white is already low-contrast.
    private func segmented(_ line: DiffLine) -> Text {
        guard let segments = line.segments, segments.count > 1 else {
            // A line the parser paired with nothing, or paired as one whole run — either way there
            // is no *unchanged* part to demote it against, so the whole line stays at full strength.
            return Text(verbatim: MonospacedGrid.expandingTabs(in: line.text))
                .fontWeight(line.kind == .conflictMarker ? .semibold : .regular)
        }
        let runs = segments.map { segment in
            Text(verbatim: MonospacedGrid.expandingTabs(in: segment.text))
                .foregroundStyle(segment.isChanged ? HierarchicalShapeStyle.primary : .secondary)
        }
        // Interpolated rather than concatenated with `+`, which iOS 26 deprecated. The per-run
        // styling survives interpolation and nothing is inserted between the runs, which matters
        // here more than anywhere else in the app: a separator would be a character of code that is
        // not in the file.
        return runs.dropFirst().reduce(runs[0]) { line, run in Text("\(line)\(run)") }
    }

    /// 10% of the semantic colour in light and 16% in dark, which is design §4's measurement: below
    /// that the tint is invisible against black, and above it there is nothing left for the word
    /// segment to be stronger than.
    private func tint(of line: DiffLine) -> Color {
        let alpha = colorScheme == .dark ? 0.16 : 0.10
        switch line.kind {
        case .addition: return .green.opacity(alpha)
        case .deletion: return .red.opacity(alpha)
        // The one status worth shouting about. A conflict marker arrives as an ordinary diff line,
        // so the parser's own kind is the only thing that makes it findable at all.
        case .conflictMarker: return .orange.opacity(alpha * 2)
        case .context, .noNewlineMarker: return .clear
        }
    }

    private var numbered: [(offset: Int, element: DiffLine)] {
        // Indexed rather than keyed on the line: two blank context lines in one file are equal, and
        // a `ForEach` over equal identities draws one of them.
        Array(lines.enumerated())
    }

    private var highestOldNumber: Int {
        lines.compactMap(\.oldNumber).max() ?? 0
    }

    private var highestNewNumber: Int {
        lines.compactMap(\.newNumber).max() ?? 0
    }

    /// Stated once because two stacks depend on it.
    ///
    /// Taken from the font rather than guessed at a ratio: a row holding `図` is taller than one
    /// holding `142` if either is allowed to size itself, and one row taller than its own number
    /// misaligns every row under it in the file.
    private var rowHeight: CGFloat {
        DiffLineHeight.at(pointSize: Self.codePointSize)
    }
}
