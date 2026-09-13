import SwiftUI

import ClientViewerDomain
import CoreDiffDomain

/// What a file draws in the height it reserved, before its diff has arrived — and after the Mac has
/// refused to send it.
///
/// **The box is not a state waiting to be filled; it is a length of the code grid the file has not
/// arrived to occupy.** So it is drawn as that: one row of type saying who is doing the asking, and
/// one 7pt bar per remaining reserved row. That is design §9's answer to the thing that makes this
/// region hard — the reserved height is `max(1, estimatedLineCount)` rows and is 18pt at one end and
/// several thousand at the other, so a treatment sized to *itself* looks like two different things,
/// and one centred on its own height reflows the moment the hunks land.
///
/// **It is short, and it does not pretend to be the file that is coming.** The first build reserved
/// `estimatedLineCount` rows and that number cannot be right: the server counts *diff lines* and a
/// drawn file is diff lines plus a torn expander wherever the diff skipped something, which nothing
/// on the wire reports. So the block is capped at four rows — enough to read as *a file is arriving*,
/// short enough that the real content growing into place is a movement rather than a collapse.
///
/// **Nothing here prints the estimate**, and with the height no longer claiming to be the file's that
/// matters more rather than less: the bars are ragged and uncountable and the figure column is empty,
/// so there is no number for the arriving content to contradict.
///
/// The sentence is the first row and stays there. An earlier build made it sticky inside its own box
/// so a reader sitting in 5,400pt of reserved height kept the words under the pinned header; a
/// four-row card has no inside to sit in, so the rule went with the height that justified it.
public struct DiffAwaitingBody: View {

    /// The bar, in the 18pt row it stands in the middle of.
    static let barHeight: CGFloat = 7
    static let barCornerRadius: CGFloat = 3.5

    /// Between the longest bar and the trailing bezel, which is the only measurement here that is
    /// not taken from the gutter.
    static let trailingInset: CGFloat = 16

    /// The narrowest and widest a bar may be, as a share of the room after the code's origin.
    static let narrowestBar = 0.34
    static let widestBar = 0.86

    /// How wide the sweep is as a share of the card, and how long it takes to cross.
    static let sweepWidth = 0.26
    static let sweepDuration: TimeInterval = 2.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether the light has started crossing. Held here rather than driven by a timeline, because a
    /// per-second rebuild of a view inside this scroll is a rebuild of the scroll.
    @State private var isSweeping = false

    private let file: FileChange
    private let wait: DiffFileWait
    private let rows: Int
    private let pointSize: CGFloat

    public init(file: FileChange, wait: DiffFileWait, rows: Int, pointSize: CGFloat) {
        self.file = file
        self.wait = wait
        self.rows = rows
        self.pointSize = pointSize
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sentence
            bars
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Stated rather than left to the stack, which is the same rule the two gutter columns follow:
        // the height this occupies is the height the entry reserved, and a body that measured itself
        // would be a second answer to a question `ContinuousDiffEntry` has already given.
        .frame(height: boxHeight, alignment: .top)
        .overlay { sweep }
        // **Nothing here is a target.** The gutter's strip takes a tap and a long press for comments,
        // and there is no line here to comment on — without this the app grows a selection on a row
        // that does not exist.
        .allowsHitTesting(false)
        .clipped()
    }

    /// The first reserved row, and the only thing in this body VoiceOver is told about.
    ///
    /// **The bars do not exist to it**, because they say nothing the sentence does not, and a file
    /// landing would otherwise take three hundred elements out of a rotor.
    private var sentence: some View {
        HStack(spacing: 0) {
            // Empty, because there is no line here and therefore no number. Reserved rather than
            // dropped, so the sentence begins where this file's code will begin.
            Color.clear
                .frame(width: figureColumnWidth)
            marker
                .frame(width: DiffGutter.markerWidth)
            Text(wait.sentence)
                .font(.system(size: pointSize, design: .monospaced))
                .foregroundStyle(wait.isFailed ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .lineLimit(1)
                .padding(.leading, DiffGutter.markerTrailingSpace)
            Spacer(minLength: 0)
        }
        .frame(height: lineHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(wait.sentence))
    }

    /// Where a `+` or a `−` would be, the one glyph that says which of the two rows this is.
    ///
    /// **The diff's own vocabulary taking a third word**, rather than a badge borrowed from
    /// somewhere else: a reader already reads this column for what happened to a line.
    @ViewBuilder private var marker: some View {
        if wait.isFailed {
            Text(verbatim: "!")
                .font(.system(size: pointSize, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    /// One bar per remaining reserved row, ragged so the block reads as code rather than as a grid.
    ///
    /// A row each rather than one drawing of all of them, which is what the real content costs for
    /// the same file and keeps every bar an ordinary view — so Reduced Motion, the appearance and the
    /// failed weight all reach them without a second code path.
    ///
    /// The one `GeometryReader` in this view, and it is safe because the height it is given is
    /// already known: it reads the width the card was handed rather than proposing one.
    private var bars: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(barShares.enumerated()), id: \.offset) { _, share in
                    RoundedRectangle(cornerRadius: Self.barCornerRadius, style: .continuous)
                        .fill(Color.diffBand)
                        // **Half weight when the block has stopped**, which with the sweep gone is
                        // what makes five quiet sentences legible as one event from across the room.
                        .opacity(wait.isFailed ? 0.5 : 1)
                        .frame(width: width(of: share, in: proxy.size.width), height: Self.barHeight)
                        .frame(height: lineHeight)
                        .padding(.leading, codeOrigin)
                }
            }
        }
        .frame(height: CGFloat(max(0, rows - 1)) * lineHeight)
        .accessibilityHidden(true)
    }

    /// One slow crossing of the whole card, and it is a material rather than an instrument.
    ///
    /// **It does not advance, fill, count or finish**, so it claims nothing the server cannot
    /// produce — which is the objection that kept a spinner off this screen for eight releases,
    /// answered rather than reversed. One sweep per card, not one per row, so a 300-row file is one
    /// moving thing.
    ///
    /// **Absent under Reduced Motion rather than slowed**, which is the state swap `SPEC.md` asks
    /// for — and it is also the form every baseline photographs, because an infinite repeat has no
    /// frame a raster can be pinned to.
    @ViewBuilder private var sweep: some View {
        if reduceMotion == false, wait.isFailed == false {
            GeometryReader { proxy in
                LinearGradient(
                    colors: [Color.diffSweep.opacity(0), .diffSweep, Color.diffSweep.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: proxy.size.width * Self.sweepWidth)
                .offset(x: isSweeping ? proxy.size.width : -proxy.size.width * Self.sweepWidth)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.linear(duration: Self.sweepDuration).repeatForever(autoreverses: false)) {
                    isSweeping = true
                }
            }
        }
    }

    private var lineHeight: CGFloat { DiffLineHeight.at(pointSize: pointSize) }

    private var boxHeight: CGFloat { CGFloat(rows) * lineHeight }

    /// The column the numbers would be in, sized from the only count this file has.
    ///
    /// **The Mac's estimate rather than a constant**, so the sentence begins where the code begins —
    /// about 48pt at two figures on the phone and wider on a file with a thousand lines in it. Taking
    /// it from the same function the code rows take it from is what makes the phone's 11pt and the
    /// iPad's 12pt one rule rather than two numbers to maintain.
    private var figureColumnWidth: CGFloat {
        DiffGutter.columnWidth(forHighestLineNumber: file.estimatedLineCount, atPointSize: pointSize)
    }

    private var codeOrigin: CGFloat {
        figureColumnWidth + DiffGutter.markerWidth + DiffGutter.markerTrailingSpace
    }

    private func width(of share: Double, in card: CGFloat) -> CGFloat {
        let room = max(0, card - codeOrigin - Self.trailingInset)
        return max(Self.barCornerRadius * 2, room * share)
    }

    /// Every bar's width, as a share of the room after the code's origin, in rows after the sentence.
    ///
    /// **Seeded from the file's own identifier**, so one file's block is the same block on every
    /// render — a raggedness that changed between two frames would be the one thing on this screen
    /// that moves for no reason, and it would make a baseline unrecordable. Folded by hand rather
    /// than through `Hashable`, because Swift seeds `hashValue` per process and the picture would
    /// differ between two launches of the same app.
    ///
    /// A share rather than a width, so the ragged edge survives the iPad's wider pane instead of
    /// leaving a column of white down the right of it.
    private var barShares: [Double] {
        guard rows > 1 else { return [] }
        var random = FoldedRandom(seed: file.id.rawValue)
        var shares: [Double] = []
        while shares.count < rows - 1 {
            // One to four rows at a width, which is what stops the block reading as a grid.
            let run = 1 + Int(random.next(below: 4))
            let span = Self.widestBar - Self.narrowestBar
            let share = Self.narrowestBar + Double(random.next(below: 1_000)) / 1_000 * span
            for _ in 0..<min(run, rows - 1 - shares.count) {
                shares.append(share)
            }
        }
        return shares
    }

}

// MARK: -

/// Enough randomness to make a block of bars look like code, and none of the kind that changes
/// between two runs.
///
/// `Hasher` is seeded per process, so a picture built from `hashValue` is a different picture every
/// launch — invisible in the app and fatal to a baseline. This folds the identifier's own bytes
/// instead, which is the same answer every time for the same file and a different one for the file
/// beside it.
private struct FoldedRandom {

    private var state: UInt64

    init(seed: String) {
        // FNV-1a over the identifier's bytes, then a non-zero floor so an empty string still steps.
        var folded: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            folded = (folded ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        state = folded | 1
    }

    /// The next value in `0..<bound`, from a plain xorshift — the picture only has to be irregular.
    mutating func next(below bound: UInt64) -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state % bound
    }
}
