import SwiftUI

import ClientViewerDomain
import CoreDiffDomain
import CoreReviewDomain

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
/// to arrive at independently. See `.ai/docs/decisions.md`.
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
///
/// **A paired run opens into two columns when the reader asks, and nothing else does.** That is
/// design §4.1's call 1 and the whole of what `isSplit` changes here: `SplitDiffRow` decides which
/// rows are blocks, `SplitBlockLayout` decides whether the row is wide enough to hold any, and every
/// layer below draws a block row differently and an ordinary row exactly as before. Context keeps its
/// 49 characters; a cell gets 22.
///
/// **A block's cells are drawn outside the horizontal scroll and ride the offset it reports**, which
/// is the one part of the return that could not be built as written. Design §4.1 asks for "one drag
/// moves the context and both cells together" and reaches for the shared hunk scroll to get it — but
/// content inside a `ScrollView` travels as one piece, so two cells at fixed positions cannot both
/// stay put while it slides. Reading the offset and applying it to each cell gives the same sentence
/// from the other end: one scroll, one gesture, and nothing that can desynchronise. In
/// `.ai/docs/decisions.md`.
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

    /// Whether the reader has asked for two columns.
    ///
    /// **Asked for rather than granted.** Whether any block is actually drawn is this view's own
    /// answer, because it depends on a width only the layout knows — below `SplitBlockLayout`'s floor
    /// the rows draw unified however the flag is set, and the control that set it says why.
    private let isSplit: Bool

    /// The stretches of comment rail this hunk draws, decided by `CommentRail` in `Domain`.
    private let runs: [CommentRun]

    /// The file's lexed code, if any of it has arrived. Empty is the ordinary first state.
    private let highlighted: HighlightedFile

    /// Whether the gutter takes gestures at all.
    ///
    /// **False while any sheet is up, and that is not belt and braces.** The composer's own detent
    /// enables background interaction so the reader can scroll the diff behind it — which also puts a
    /// live gutter under a sheet. Every gesture that lands there is discarded by the draft's state
    /// machine, so what reached the reader was a haptic for a hold that did not happen. The scroll
    /// still moves; only the target goes.
    private let acceptsTargeting: Bool

    private let onTap: (DiffLinePosition) -> Void
    private let onLongPress: (DiffLinePosition) -> Void

    @State private var visibleWidth: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var scrolledBy: CGFloat = 0

    /// The whole row's width, which is what decides whether a block fits in it.
    ///
    /// Measured rather than handed in, because the answer differs between the phone, the iPad's pane
    /// beside the selector, and a Mac window the reader is dragging — and the last of those changes
    /// while the view is on screen.
    @State private var rowWidth: CGFloat = 0

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
        isSplit: Bool = false,
        runs: [CommentRun] = [],
        highlighted: HighlightedFile = .none,
        acceptsTargeting: Bool = true,
        onTap: @escaping (DiffLinePosition) -> Void = { _ in },
        onLongPress: @escaping (DiffLinePosition) -> Void = { _ in }
    ) {
        self.lines = lines
        self.highestNumber = highestNumber
        self.pointSize = pointSize
        self.isSplit = isSplit
        self.runs = runs
        self.highlighted = highlighted
        self.acceptsTargeting = acceptsTargeting
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                tints
                selection
                columns
                blockCells
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
        // Watched rather than read once: a Mac window is dragged while this is on screen, and
        // crossing the floor has to close the blocks as it happens rather than at the next layout
        // that happened to be asked for.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            rowWidth = width
        }
        .sensoryFeedback(.selection, trigger: holds)
    }

    // MARK: - What is drawn

    /// Whether any block is actually drawn, which is the reader's ask and the room agreeing.
    ///
    /// Below `SplitBlockLayout`'s floor this is false however `isSplit` is set, and the toolbar item
    /// that set it goes disabled carrying its reason — `SPEC.md`'s third permitted state for a
    /// control, and the one that re-enables itself on the drag back.
    private var drawsBlocks: Bool {
        isSplit && SplitBlockLayout.fits(
            rowWidth: rowWidth,
            highestLineNumber: highestNumber,
            atPointSize: pointSize,
            trailingInset: Self.codeTrailingInset
        )
    }

    private var rows: [SplitDiffRow] {
        SplitDiffRow.rows(of: lines, splitting: drawsBlocks)
    }

    /// The rails as *drawn* rows, which is not the same as the runs once two lines share one.
    private var segments: [SplitRailSegment] {
        SplitCommentRail.segments(of: runs, in: lines, splitting: drawsBlocks)
    }

    private var indexedRows: [(offset: Int, element: SplitDiffRow)] {
        // Indexed rather than keyed on the row: two blank context lines in one file are equal, and
        // a `ForEach` over equal identities draws one of them.
        Array(rows.enumerated())
    }

    // MARK: - The layers

    /// A strip per row, full width, behind everything. Outside the scroll on purpose: a tint that
    /// slid away with the code would stop saying which side the line is on halfway through a long
    /// one.
    ///
    /// **Inside a block the tint is the cell's rather than the row's**, which is design §4.3: in two
    /// columns the side is positional, so the colour covers a cell's figures and its code and stops
    /// at the rule.
    private var tints: some View {
        VStack(spacing: 0) {
            ForEach(indexedRows, id: \.offset) { _, row in
                switch row {
                case .full(let line):
                    tint(of: line)
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                case .block(let old, let new):
                    HStack(spacing: 0) {
                        cellTint(of: old)
                        Color.clear.frame(width: SplitBlockLayout.gap)
                        // The one thing that says a block continues past an empty cell.
                        Color.diffBlockRule.frame(width: SplitBlockLayout.ruleWidth)
                        Color.clear.frame(width: SplitBlockLayout.gap)
                        cellTint(of: new)
                        Spacer(minLength: 0)
                    }
                    .frame(height: rowHeight)
                }
            }
        }
    }

    /// **An absent side draws nothing at all**, which is design §4.1's call 2. A tint would claim the
    /// side has a line there and hatching would be a new drawn texture in an app that owns one, so
    /// the card shows through — and absence reads as absence when everything around it is a filled
    /// rectangle.
    @ViewBuilder private func cellTint(of line: DiffLine?) -> some View {
        if let line {
            tint(of: line).frame(width: cellWidth)
        } else {
            Color.clear.frame(width: cellWidth)
        }
    }

    /// The run being picked out, tinted across the row — or across the one cell it is in.
    ///
    /// **Only the pending run, and that is design §7 disagreeing with itself on purpose.** §7.3
    /// rejects a row tint for a *saved* comment — it would need a third colour reading as both itself
    /// and the `+`/`−` beneath it, and the word-diff background is already the loudest thing in the
    /// row. §7.1 asks for one for the *held* state, which is a different job: it is not a mark that
    /// has to live beside a diff for as long as the reader is reading, it is a selection that lasts a
    /// few seconds and has to be unmissable while it does.
    ///
    /// Outside the horizontal scroll with the tints, so a held run stays held while the code slides
    /// under it — §7.1's second rule.
    private var selection: some View {
        ForEach(segments.filter(\.isPending)) { segment in
            Color.diffCommentRail.opacity(selectionAlpha)
                .frame(
                    width: segment.side == nil ? rowWidth : cellWidth,
                    height: rowHeight * CGFloat(segment.rowCount)
                )
                .offset(x: leadingEdge(of: segment.side), y: rowHeight * CGFloat(segment.firstRow))
        }
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: 0) {
            numbers
            markers
            code
        }
    }

    /// **A block row's figures belong to its cells, so the file's own column leaves that row empty.**
    /// Design §4.3's call 3: one shared column cannot say which side it numbers on the rows where the
    /// two differ, and inside a block most rows are exactly that.
    private var numbers: some View {
        VStack(spacing: 0) {
            ForEach(indexedRows, id: \.offset) { offset, row in
                switch row {
                case .full(let line):
                    figure(of: line, isPending: isPending(row: offset, side: nil))
                        .frame(height: rowHeight)
                case .block:
                    Color.clear.frame(width: numberColumnWidth, height: rowHeight)
                }
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
    ///
    /// **A block row carries no marker at all.** Inside one, every left row is a deletion and every
    /// right row an addition, so the glyph would be 18pt restating the column it is standing in —
    /// design §4.3. Outside a block it is untouched, so the `+` and the `−` never leave the file.
    private var markers: some View {
        VStack(spacing: 0) {
            ForEach(indexedRows, id: \.offset) { _, row in
                switch row {
                case .full(let line):
                    marker(of: line)
                        .frame(width: DiffGutter.markerWidth, height: rowHeight)
                case .block:
                    Color.clear.frame(width: DiffGutter.markerWidth, height: rowHeight)
                }
            }
        }
        .padding(.trailing, DiffGutter.markerTrailingSpace)
    }

    /// One scroll for the whole hunk rather than one per line, which is what keeps the lines aligned
    /// with each other while they move — and, once blocks exist, what keeps the context aligned with
    /// them.
    private var code: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(indexedRows, id: \.offset) { _, row in
                    switch row {
                    case .full(let line):
                        segmented(line)
                            .lineLimit(1)
                            .frame(height: rowHeight, alignment: .leading)
                    case .block(let old, let new):
                        // **What a block contributes here is travel and nothing visible.** Its cells
                        // are drawn outside this scroll and ride its offset, so the only thing it
                        // needs from the content is enough width that a drag can reach the end of
                        // the longer of its two lines — which is further than the unified row needs,
                        // because a cell is narrower than this scroll's own viewport.
                        Color.clear.frame(width: travelNeeded(old, new), height: rowHeight)
                    }
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
        .frame(height: contentHeight)
        // **Masked rather than overlaid with a colour.** The row tints are drawn *behind* this
        // scroll, so a gradient painted in the background colour would have to composite the tint
        // back on top of itself to avoid a grey notch on every added and removed row. Fading the
        // code away instead reveals whatever is behind it, which is already the right colour in both
        // appearances and over every tint.
        .mask(alignment: .leading) { fade }
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

    private var fade: some View {
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

    /// The two cells of every block, drawn over the pinned columns and moving with the scroll.
    private var blockCells: some View {
        VStack(spacing: 0) {
            ForEach(indexedRows, id: \.offset) { offset, row in
                switch row {
                case .full:
                    Color.clear.frame(height: rowHeight)
                case .block(let old, let new):
                    HStack(spacing: 0) {
                        cell(of: old, at: offset, on: .old)
                        Color.clear.frame(width: 2 * SplitBlockLayout.gap + SplitBlockLayout.ruleWidth)
                        cell(of: new, at: offset, on: .new)
                        Spacer(minLength: 0)
                    }
                    .frame(height: rowHeight)
                }
            }
        }
    }

    /// One cell: its own figure column, pinned, and its own clipped view onto the code.
    ///
    /// The code is offset by the hunk's own scroll rather than by a scroll of its own, which is what
    /// makes one drag move both cells and the context around them without anything to synchronise.
    @ViewBuilder private func cell(of line: DiffLine?, at row: Int, on side: DiffSide) -> some View {
        if let line {
            HStack(spacing: 0) {
                figure(of: line, isPending: isPending(row: row, side: side))
                segmented(line)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: -scrolledBy)
                    .frame(width: cellCodeWidth, height: rowHeight, alignment: .leading)
                    .clipped()
                    .mask(alignment: .leading) { fade }
            }
            .frame(width: cellWidth, height: rowHeight, alignment: .leading)
        } else {
            Color.clear.frame(width: cellWidth, height: rowHeight)
        }
    }

    /// One capsule per stretch, positioned by row rather than by point so the arithmetic is the same
    /// one the tints and the numbers already agree on.
    ///
    /// **Square caps mean pending and round caps mean saved.** Design §7.1 makes it a difference in
    /// shape rather than in colour, so the state survives a greyscale screenshot, a dimmed one, and a
    /// reader who cannot tell indigo from blue.
    private var rails: some View {
        ForEach(segments) { segment in
            // One shape rather than two, because the difference *is* the corner: a square-capped rail
            // is a run still being picked out and a round-capped one is a comment that exists.
            RoundedRectangle(cornerRadius: segment.isPending ? 0 : DiffGutter.railWidth / 2, style: .continuous)
                .fill(Color.diffCommentRail)
                .frame(width: DiffGutter.railWidth, height: rowHeight * CGFloat(segment.rowCount))
                .offset(x: leadingEdge(of: segment.side), y: rowHeight * CGFloat(segment.firstRow))
        }
        .accessibilityHidden(true)
    }

    // MARK: - The target

    /// Everything to the left of the code, taking both gestures and drawing nothing.
    ///
    /// **A tap and a long press, resolved by arithmetic rather than by hit testing.** The alternative
    /// — a `contentShape` per row — needs 44pt to be a legal target, which overhangs its neighbours
    /// by 13pt on each side and leaves three rows claiming one point with z-order deciding. This has
    /// one answer everywhere in it.
    ///
    /// **In split there are two strips rather than one**, each the cell's own figures: smaller than
    /// the unified strip's 51pt, and unambiguous about which side it meant.
    @ViewBuilder private var tapStrip: some View {
        if acceptsTargeting {
            if drawsBlocks {
                HStack(spacing: 0) {
                    strip(on: .old, width: numberColumnWidth)
                    Color.clear.frame(width: cellWidth - numberColumnWidth + 2 * SplitBlockLayout.gap + SplitBlockLayout.ruleWidth)
                    strip(on: .new, width: numberColumnWidth)
                    Spacer(minLength: 0)
                }
                .frame(height: contentHeight)
            } else {
                strip(
                    on: nil,
                    width: DiffGutter.tapStripWidth(forHighestLineNumber: highestNumber, atPointSize: pointSize)
                )
            }
        }
    }

    private func strip(on side: DiffSide?, width: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: contentHeight)
            .contentShape(.rect)
            .gesture(
                SpatialTapGesture().onEnded { touch in
                    if let row = position(at: touch.location.y, on: side) {
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
                                  let row = position(at: touch.startLocation.y, on: side) else { return }
                            isPressing = true
                            holds += 1
                            onLongPress(row)
                        }
                    }
                    .onEnded { _ in isPressing = false }
            )
    }

    /// Which line a touch meant, and nothing when no row there can carry a comment.
    ///
    /// **The arithmetic is `GutterTarget`'s and not this view's**, which is the same seam the
    /// unified strip already used: deciding which line a coordinate points at is a fact about the
    /// model, and a view body is the one place in this codebase where that cannot be asserted
    /// directly. What is left here is handing over the two things only the view knows — the height
    /// of a row, and which cell's strip was touched.
    private func position(at y: CGFloat, on side: DiffSide?) -> DiffLinePosition? {
        GutterTarget.line(at: y, on: side, of: rows, lines: lines, rowHeight: rowHeight)
    }

    // MARK: - The indicator

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

    // MARK: - One row's parts

    /// Never blank now, which is the review's first fault answered: a deletion shows the old side's
    /// number and everything else the new side's, so a reader who wants to say "line 6 is wrong" has
    /// something to point at on every row.
    /// **The figure goes indigo while its row is held**, which is §7.1's frames and the one place the
    /// selection reaches a glyph rather than a background. It is what makes the run readable when the
    /// tint under it is competing with an added row's green — and it is the gutter's own column
    /// saying which rows the comment will be about, which is the question the reader is answering.
    private func figure(of line: DiffLine, isPending: Bool) -> some View {
        Text(DiffGutter.number(of: line).map(String.init) ?? "")
            .foregroundStyle(isPending ? AnyShapeStyle(Color.diffCommentRail) : AnyShapeStyle(.tertiary))
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
    /// back to the specification on 28 August 2026. In `.ai/docs/decisions.md`.
    ///
    /// **So the alpha is derived rather than drawn.** §4's argument that "stronger" is a ratio still
    /// holds, and it is the thing that survives: the changed run reads at three times the row's own
    /// tint in both appearances, and what the segment's own alpha has to be for that is arithmetic
    /// over what it composites onto rather than a number picked per appearance.
    ///
    /// **It matters more inside a block than anywhere else**, which is design §4.3's note: in a
    /// 22-character cell the background is the only thing left saying *this part*.
    private func segmented(_ line: DiffLine) -> Text {
        let drawn = DrawnDiffLine.of(line)
        var attributed = lexed(drawn, of: line) ?? AttributedString(drawn.text)
        guard drawn.changed.isEmpty == false else {
            // A line the parser paired with nothing, or paired as one whole run — either way there
            // is no *unchanged* part to tell it apart from, and a background over the whole line
            // would be a second, stronger copy of the row tint drawn on top of the row tint.
            return Text(attributed)
                .fontWeight(line.kind == .conflictMarker ? .semibold : .regular)
        }
        let characters = attributed.characters
        for range in drawn.changed {
            let start = characters.index(characters.startIndex, offsetBy: range.lowerBound)
            let end = characters.index(characters.startIndex, offsetBy: range.upperBound)
            attributed[start..<end].backgroundColor = segmentTint(of: line)
        }
        return Text(attributed)
    }

    /// The row's code as the lexer coloured it, or nothing when it is to be drawn plain.
    ///
    /// **The two treatments compose because they use different properties**, which is the whole of
    /// why design §4's word diff was reverted to `SPEC.md` §10's background on 28 August 2026: a lexer
    /// owns the text colour, so the changed run has to be a background or the two cannot both be on
    /// screen. The order here is that order — colours first, the word-diff background over them.
    ///
    /// **The lengths are checked, and that is a guard on a JavaScript engine behind a bridge.** The
    /// lexer is handed the same expansion `DrawnDiffLine` produces, so the two agree by construction
    /// — except where highlight.js's own HTML round trip decodes something that was literal text in
    /// the file, which shortens the line. Applying a background at an offset into a shorter string
    /// either traps or paints the wrong word, and neither is worth a colour: this row draws plain and
    /// the rest of the file keeps its highlighting.
    private func lexed(_ drawn: DrawnDiffLine, of line: DiffLine) -> AttributedString? {
        guard let text = highlighted.text(of: line), text.characters.count == drawn.text.count else {
            return nil
        }
        return text
    }

    /// The changed run's own background, chosen so that what lands on screen is three times the row
    /// tint it sits on.
    ///
    /// Two translucent layers do not add, they composite — `1 - (1 - t)(1 - s)` — so a segment drawn
    /// at a fixed 28% reads as a different multiple of the row in each appearance, which is exactly
    /// the drift design §4 rejected the treatment for. Solving for the alpha that reaches `3t`
    /// instead keeps the *ratio* fixed and lets the number move.
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

    /// **Two thirds again over the row tints**, which is what §7's frames measure: 14% in light and
    /// 20% in dark, against the 6% and 10% an added or removed row carries. A selection has to win
    /// against the tint it is drawn over, and it is the only thing on screen that has to.
    private var selectionAlpha: Double {
        colorScheme == .dark ? 0.20 : 0.14
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

    /// Whether this drawn row, in this cell, is inside the run being picked out.
    private func isPending(row: Int, side: DiffSide?) -> Bool {
        segments.contains { segment in
            segment.isPending
                && segment.side == side
                && row >= segment.firstRow
                && row < segment.firstRow + segment.rowCount
        }
    }

    // MARK: - The arithmetic two stacks agree on

    private var numberColumnWidth: CGFloat {
        DiffGutter.columnWidth(forHighestLineNumber: highestNumber, atPointSize: pointSize)
    }

    private var cellWidth: CGFloat {
        SplitBlockLayout.cellWidth(inRowWidth: rowWidth, trailingInset: Self.codeTrailingInset)
    }

    private var cellCodeWidth: CGFloat {
        SplitBlockLayout.codeWidth(
            inCellWidth: cellWidth,
            highestLineNumber: highestNumber,
            atPointSize: pointSize
        )
    }

    /// Where a cell begins, measured from the leading edge of the whole row.
    private func leadingEdge(of side: DiffSide?) -> CGFloat {
        side == .new ? cellWidth + 2 * SplitBlockLayout.gap + SplitBlockLayout.ruleWidth : 0
    }

    /// How much scroll a block row needs behind it so a drag can reach the end of its longer line.
    ///
    /// A cell is narrower than this scroll's own viewport, so a block needs *more* travel than the
    /// unified row holding the same text would: the viewport's width, plus however far past the cell
    /// the line runs.
    private func travelNeeded(_ old: DiffLine?, _ new: DiffLine?) -> CGFloat {
        let columns = max(old?.displayColumns ?? 0, new?.displayColumns ?? 0)
        let lineWidth = CGFloat(columns) * DiffGutter.advanceWidth(atPointSize: pointSize)
        return visibleWidth + max(0, lineWidth - cellCodeWidth)
    }

    private var contentHeight: CGFloat {
        rowHeight * CGFloat(rows.count)
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
