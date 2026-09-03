import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// One hunk's diff lines with wrap off: the numbers and markers pinned, and the code scrolling under
/// them.
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
///
/// **One number column and a marker beside it, which is the diff design review's rules 1 and 2.**
/// They arrived together and only work together: `design.md` §4 had rejected a single interleaved
/// column because "it looks like one sequence and is two", and the `+`/`−` column is what answers
/// that — it says which side you are reading, so the figure no longer has to. What it costs is three
/// characters of code, and the review's own argument for spending them is that the row which used to
/// hold them was already cut off without saying so. Davide adopted both on 1 September 2026.
public struct DiffFileLines: View {

    /// §4's inset between the last character of code and the trailing edge.
    public static let codeTrailingInset: CGFloat = 12

    /// The width of the fade at the trailing edge, and the review's answer to its third fault.
    ///
    /// `extension Lce: Sendable where C: Sendable, E: Sendable` is 57 characters and the row fitted
    /// 56, so it looked complete and was not — four files on the photographed screen hid their
    /// closing brace that way. A clipped edge that fades never reads as an end.
    public static let trailingFade: CGFloat = 26

    /// The always-visible scroll indicator under a hunk that overflows.
    ///
    /// The system's own indicator is transient, and a horizontal axis nobody knows is there is a
    /// gesture nobody makes. Three points, drawn per hunk, and absent entirely when the hunk fits —
    /// an indicator over content that cannot scroll is a control that does nothing.
    public static let indicatorHeight: CGFloat = 3

    /// The shortest the thumb is allowed to get, so a file whose longest line runs to ten screens
    /// still shows something you can see rather than a dot.
    static let shortestIndicator: CGFloat = 24

    private let lines: [DiffLine]
    private let highestNumber: Int
    private let pointSize: CGFloat

    /// The stretches of comment rail this hunk draws, decided by `CommentRail` in `Domain`.
    private let runs: [CommentRun]

    private let onTap: (DiffLinePosition) -> Void
    private let onLongPress: (DiffLinePosition) -> Void

    @State private var visibleWidth: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var scrolledBy: CGFloat = 0

    /// Bumped when a long press is recognised, so the haptic is a declarative consequence of a state
    /// change rather than a call into the system from inside a view body.
    @State private var holds = 0

    /// Whether the current press has already been reported, so one hold marks one row.
    @State private var isPressing = false

    @Environment(\.colorScheme) private var colorScheme

    /// The highest number is handed in rather than taken from these lines, because a hunk is not a
    /// file: sized per hunk, the column would step in and out as the reader scrolled, which is a
    /// gutter that changes width mid-file. Design §4 sizes it from the file's own maximum.
    ///
    /// **The two gestures report a row and not a file**, because a hunk does not hold a `FileID` and
    /// the view that does — `DiffFileContent` — re-attaches its own on the way back up. That is the
    /// same seam `onExpand` already uses, and it is one fewer place for the wrong identifier to be
    /// attached.
    public init(
        lines: [DiffLine],
        highestNumber: Int,
        pointSize: CGFloat,
        runs: [CommentRun] = [],
        onTap: @escaping (DiffLinePosition) -> Void = { _ in },
        onLongPress: @escaping (DiffLinePosition) -> Void = { _ in }
    ) {
        self.lines = lines
        self.highestNumber = highestNumber
        self.pointSize = pointSize
        self.runs = runs
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                tints
                columns
            }
            .font(.system(size: pointSize, design: .monospaced))
            // **Overlaid rather than added to the row, which is the whole of design §7.3's call 7.**
            // A fourth column in `columns` would widen the gutter by 3pt and desynchronise two
            // constants that are computed rather than measured — the scroll indicator's leading inset
            // and `DiffExpander`'s code origin — so every torn row and every thumb would sit 3pt off
            // the code they belong to. An overlay takes no space at all, and the space it draws in is
            // the 4pt of leading inset that no figure ever reaches.
            .overlay(alignment: .topLeading) { rails }
            // **The target, and it is one strip rather than a control per row.** See `GutterTarget`
            // for why an 18pt row is allowed to be the unit here: this has no boundaries in it and no
            // dead space, so a miss cannot produce nothing.
            .overlay(alignment: .topLeading) { tapStrip }
            indicator
        }
        .sensoryFeedback(.selection, trigger: holds)
    }

    /// One capsule per stretch, positioned by row rather than by point so the arithmetic is the same
    /// one the tints and the numbers already agree on.
    ///
    /// **Square caps mean pending and round caps mean saved.** Design §7.1 makes it a difference in
    /// shape rather than in colour, so the state survives a greyscale screenshot, a dimmed one, and a
    /// reader who cannot tell indigo from blue.
    private var rails: some View {
        ForEach(runs) { run in
            // One shape rather than two, because the difference *is* the corner: a square-capped rail
            // is a run still being picked out and a round-capped one is a comment that exists.
            RoundedRectangle(cornerRadius: run.isPending ? 0 : DiffGutter.railWidth / 2, style: .continuous)
                .fill(Color.diffCommentRail)
                .frame(width: DiffGutter.railWidth, height: rowHeight * CGFloat(run.rowCount))
                .offset(y: rowHeight * CGFloat(run.firstRow))
        }
        .accessibilityHidden(true)
    }

    /// Everything to the left of the code, taking both gestures and drawing nothing.
    ///
    /// **A tap and a long press, resolved by arithmetic rather than by hit testing.** The alternative
    /// — a `contentShape` per row — needs 44pt to be a legal target, which overhangs its neighbours
    /// by 13pt on each side and leaves three rows claiming one point with z-order deciding. This has
    /// one answer everywhere in it.
    private var tapStrip: some View {
        Color.clear
            .frame(
                width: DiffGutter.tapStripWidth(forHighestLineNumber: highestNumber, atPointSize: pointSize),
                height: rowHeight * CGFloat(lines.count)
            )
            .contentShape(.rect)
            .gesture(
                SpatialTapGesture().onEnded { touch in
                    if let row = row(at: touch.location.y) {
                        onTap(row)
                    }
                }
            )
            // **Sequenced with a zero-distance drag purely to learn where the finger is.** A bare
            // `onLongPressGesture` reports that a press happened and not where, and where is the
            // whole question. The press has to win before the drag begins, which is also what keeps
            // this from competing with the vertical scroll: until 0.35s has passed, the pan is the
            // scroll's.
            .gesture(
                LongPressGesture(minimumDuration: 0.35)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { phase in
                        switch phase {
                        // The press is still being held and has not won yet.
                        case .first:
                            isPressing = false
                        // **Once per press, not once per frame.** A zero-distance drag reports every
                        // movement of a finger that is already down, and a hold that fired on each of
                        // them would re-mark the row and re-fire the haptic all the way through a
                        // press.
                        case .second(let recognised, let touch):
                            guard recognised, isPressing == false, let touch,
                                  let row = row(at: touch.startLocation.y) else { return }
                            isPressing = true
                            holds += 1
                            onLongPress(row)
                        }
                    }
                    .onEnded { _ in isPressing = false }
            )
    }

    /// Which row a touch meant, and nothing when no row there can carry a comment.
    private func row(at y: CGFloat) -> DiffLinePosition? {
        guard let index = GutterTarget.row(at: y, of: lines, rowHeight: rowHeight) else { return nil }
        return DiffLinePosition.of(lines[index])
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
            markers
            code
        }
    }

    private var numbers: some View {
        VStack(spacing: 0) {
            ForEach(numbered, id: \.offset) { _, line in
                figure(of: line)
                    .frame(height: rowHeight)
            }
        }
    }

    /// **The strongest colour in a row lives here rather than behind the code**, which is rule 2's
    /// whole argument. It frees the row tint to be almost nothing, and it is the only marker that
    /// survives red-green colour blindness, sunlight, and a chat client that dims the screenshot.
    ///
    /// Outside the horizontal scroll with the numbers: a marker that scrolled away would leave the
    /// row saying nothing on exactly the long lines the reader had to scroll to read.
    /// **The gap after it is on the column rather than on the glyph**, so the `+` and the `−` stay
    /// centred in one another's width down the file while the code clears them — a padding inside the
    /// frame would move the glyph instead of the code.
    private var markers: some View {
        VStack(spacing: 0) {
            ForEach(numbered, id: \.offset) { _, line in
                marker(of: line)
                    .frame(width: DiffGutter.markerWidth, height: rowHeight)
            }
        }
        .padding(.trailing, DiffGutter.markerTrailingSpace)
    }

    /// One scroll for the whole hunk rather than one per line, which is what keeps the lines aligned
    /// with each other while they move.
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
            // Watched rather than read once: expanding a hunk splices longer lines into these rows,
            // and an indicator sized on the width the hunk had before the expansion is an indicator
            // that lies about how much is left.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                contentWidth = width
            }
        }
        // **Height stated, not inherited.** A `ScrollView` is greedy on both axes whatever its
        // scroll axis is, so left alone this one fills the screen — which is invisible in a
        // full-screen baseline and unbounded inside the lazy stack this file will be a section of.
        // The same arithmetic the tints behind it use, so the two trees cannot come out different
        // heights.
        .frame(height: rowHeight * CGFloat(lines.count))
        // **Masked rather than overlaid with a colour.** The row tints are drawn *behind* this
        // scroll, so a gradient painted in the background colour would have to composite the tint
        // back on top of itself to avoid a grey notch on every added and removed row. Fading the
        // code away instead reveals whatever is behind it, which is already the right colour in both
        // appearances and over every tint.
        .mask(alignment: .leading) {
            HStack(spacing: 0) {
                Rectangle()
                LinearGradient(
                    colors: [.black, .black.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: Self.trailingFade)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.x
        } action: { _, offset in
            scrolledBy = offset
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            visibleWidth = width
        }
    }

    /// The proportional thumb, and nothing at all when the hunk fits.
    ///
    /// Read from the scroll rather than driving it — `SPEC.md` §10 forbids *positioning* by content
    /// offset, and this only reports where the reader already is.
    @ViewBuilder private var indicator: some View {
        if contentWidth > visibleWidth, visibleWidth > 0 {
            let travel = contentWidth - visibleWidth
            let proportion = visibleWidth / contentWidth
            GeometryReader { proxy in
                let trackWidth = proxy.size.width
                let thumbWidth = max(Self.shortestIndicator, trackWidth * proportion)
                Capsule()
                    .fill(.tertiary)
                    .frame(width: thumbWidth, height: Self.indicatorHeight)
                    .offset(x: (trackWidth - thumbWidth) * clamped(scrolledBy / travel))
            }
            .frame(height: Self.indicatorHeight)
            .padding(.leading, numberColumnWidth + DiffGutter.markerWidth + DiffGutter.markerTrailingSpace)
            .padding(.trailing, Self.codeTrailingInset)
            .accessibilityHidden(true)
        }
    }

    /// Never blank now, which is the review's first fault answered: a deletion shows the old side's
    /// number and everything else the new side's, so a reader who wants to say "line 6 is wrong" has
    /// something to point at on every row.
    private func figure(of line: DiffLine) -> some View {
        Text(DiffGutter.number(of: line).map(String.init) ?? "")
            .foregroundStyle(.tertiary)
            .monospacedDigit()
            .frame(width: numberColumnWidth - DiffGutter.trailingSpace, alignment: .trailing)
            .padding(.trailing, DiffGutter.trailingSpace)
    }

    @ViewBuilder private func marker(of line: DiffLine) -> some View {
        switch DiffGutter.marker(of: line) {
        case .added: Text(verbatim: "+").foregroundStyle(Color.green)
        case .removed: Text(verbatim: "−").foregroundStyle(Color.red)
        // Four rows in five are context, and a glyph on each one is a column of noise the eye has to
        // filter before it can find the two that matter.
        case .unchanged: Color.clear
        }
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

    /// **Almost nothing now, which is what rule 2 bought.** The marker carries the saturation, so the
    /// row tint no longer has to compete with the word segment over it — the review's fifth fault was
    /// two states drawn in four background colours, with the strongest of them on the smallest run.
    ///
    /// Stated once because the segment's alpha is solved from it: two numbers that have to hold a
    /// ratio cannot each be written down separately.
    private var tintAlpha: Double {
        colorScheme == .dark ? 0.10 : 0.06
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

    private var numberColumnWidth: CGFloat {
        DiffGutter.columnWidth(forHighestLineNumber: highestNumber, atPointSize: pointSize)
    }

    /// Stated once because two stacks depend on it.
    ///
    /// Taken from the font rather than guessed at a ratio: a row holding `図` is taller than one
    /// holding `142` if either is allowed to size itself, and one row taller than its own number
    /// misaligns every row under it in the file.
    private var rowHeight: CGFloat {
        DiffLineHeight.at(pointSize: pointSize)
    }
}

// MARK: -

private func clamped(_ fraction: CGFloat) -> CGFloat {
    min(1, max(0, fraction))
}
