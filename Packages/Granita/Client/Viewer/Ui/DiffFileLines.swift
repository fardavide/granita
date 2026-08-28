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
    private let highestOldNumber: Int
    private let highestNewNumber: Int

    @Environment(\.colorScheme) private var colorScheme

    /// The two highest numbers are handed in rather than taken from these lines, because a hunk is
    /// not a file: sized per hunk, the column would step in and out as the reader scrolled, which
    /// is a gutter that changes width mid-file. Design §4 sizes it from the file's own maximum.
    public init(
        lines: [DiffLine],
        showsOldNumber: Bool,
        highestOldNumber: Int,
        highestNewNumber: Int
    ) {
        self.lines = lines
        self.showsOldNumber = showsOldNumber
        self.highestOldNumber = highestOldNumber
        self.highestNewNumber = highestNewNumber
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

    /// The changed run carried by a **background**, over the row's own tint.
    ///
    /// **This is `SPEC.md` §10's own treatment, and design §4 had replaced it.** The review found
    /// that two nested backgrounds do not survive dark mode — the row already needs 16% to be
    /// visible against black, leaving no headroom above it — and inverted the emphasis into the text
    /// instead, taking the unchanged runs down to secondary. That reads well and it spends the one
    /// property the syntax highlighter needs: a lexer colours text, and a line whose text colour
    /// already means *this part changed* has nothing left to say `keyword` with. Davide settled it
    /// back to the specification on 28 August 2026. In `.claude/docs/decisions.md`.
    ///
    /// **So the alpha is derived rather than drawn.** §4's argument that "stronger" is a ratio still
    /// holds, and it is the thing that survives: the changed run reads at three times the row's own
    /// tint in both appearances, and what the segment's own alpha has to be for that is arithmetic
    /// over what it composites onto rather than a number picked per appearance.
    private func segmented(_ line: DiffLine) -> Text {
        let drawn = DrawnDiffLine.of(line)
        guard drawn.changed.isEmpty == false else {
            // A line the parser paired with nothing, or paired as one whole run — either way there
            // is no *unchanged* part to tell it apart from, and a background over the whole line
            // would be a second, stronger copy of the row tint drawn on top of the row tint.
            return Text(verbatim: drawn.text)
                .fontWeight(line.kind == .conflictMarker ? .semibold : .regular)
        }
        var attributed = AttributedString(drawn.text)
        let characters = attributed.characters
        for range in drawn.changed {
            let start = characters.index(characters.startIndex, offsetBy: range.lowerBound)
            let end = characters.index(characters.startIndex, offsetBy: range.upperBound)
            attributed[start..<end].backgroundColor = segmentTint(of: line)
        }
        return Text(attributed)
    }

    /// The changed run's own background, chosen so that what lands on screen is three times the row
    /// tint it sits on.
    ///
    /// Two translucent layers do not add, they composite — `1 - (1 - t)(1 - s)` — so a segment drawn
    /// at a fixed 28% reads as a different multiple of the row in each appearance, which is exactly
    /// the drift design §4 rejected the treatment for. Solving for the alpha that reaches `3t`
    /// instead keeps the *ratio* fixed and lets the number move: about 22% in light and 38% in dark.
    private func segmentTint(of line: DiffLine) -> Color {
        let tint = tintAlpha
        let alpha = 1 - (1 - 3 * tint) / (1 - tint)
        switch line.kind {
        case .addition: return .green.opacity(alpha)
        case .deletion: return .red.opacity(alpha)
        // Neither ever carries segments — the parser pairs additions against deletions and nothing
        // else — so these are the exhaustive switch rather than a treatment.
        case .context, .noNewlineMarker, .conflictMarker: return .clear
        }
    }

    /// 10% of the semantic colour in light and 16% in dark, which is design §4's measurement: below
    /// that the tint is invisible against black, and above it there is nothing left for the word
    /// segment to be stronger than.
    ///
    /// Stated once because the segment's alpha is solved from it: two numbers that have to hold a
    /// ratio cannot each be written down separately.
    private var tintAlpha: Double {
        colorScheme == .dark ? 0.16 : 0.10
    }

    private func tint(of line: DiffLine) -> Color {
        let alpha = tintAlpha
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

    /// Stated once because two stacks depend on it.
    ///
    /// Taken from the font rather than guessed at a ratio: a row holding `図` is taller than one
    /// holding `142` if either is allowed to size itself, and one row taller than its own number
    /// misaligns every row under it in the file.
    private var rowHeight: CGFloat {
        DiffLineHeight.at(pointSize: Self.codePointSize)
    }
}
