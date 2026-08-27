import CoreDiffDomain

/// Which side of a hunk the reader asked for more of.
public enum ContextDirection: String, Hashable, Sendable, CaseIterable {
    case above
    case below
}

/// A window of one side of a file, as the client asks the Mac for it.
public struct LineWindow: Hashable, Sendable {

    public let side: DiffSide

    /// One-based, which is the route's own convention and the same numbering the gutter draws.
    public let start: Int

    public let count: Int

    public init(side: DiffSide, start: Int, count: Int) {
        self.side = side
        self.start = start
        self.count = count
    }
}

/// The lines between the hunks: which of them to ask for, and what a hunk becomes once they land.
///
/// **The position is the client's**, which is `SPEC.md` §8's reason for `/lines` being stateless: a
/// single parameter on the diff route cannot express "hunk 2 expanded up and hunk 5 expanded down",
/// so the Mac hands over raw lines and holds nothing. What this holds instead is not a second
/// bookkeeping structure beside the diff — **it is the diff**. Splicing produces a wider `Hunk`, so
/// the question "is there anything left above this one" is answered by the hunk itself and cannot
/// drift from what is drawn.
///
/// **Every window is read from the new side.** A context line is by definition identical on both,
/// the reader is reading the working copy, and the one case where the new side is missing — a
/// wholly deleted file — has no gap to expand into, because the hunk already holds every line there
/// is.
public enum ContextExpansion {

    /// How many lines one press adds.
    ///
    /// Twenty, stated rather than left to settle: at design §4's 11pt it is about a third of a phone
    /// screen, which is enough to see what encloses a change and little enough that the line the
    /// reader was on is still on screen after it moves. A press that scrolls past a full screen of
    /// new context loses their place, which is the thing expansion exists to protect.
    public static let step = 20

    /// The lines immediately above a hunk, bounded by the file's top or by the hunk before it.
    ///
    /// `nil` when the gap is empty, and that is what the header reads to decide whether to draw the
    /// control at all — design §4's chevron over nothing is the smallest possible lie.
    public static func above(_ hunk: Hunk, after previous: Hunk?) -> LineWindow? {
        let upperBound = newRange(of: hunk).lowerBound
        let gapStart = previous.map { newRange(of: $0).upperBound } ?? 1
        guard gapStart < upperBound else { return nil }
        let start = max(gapStart, upperBound - step)
        return LineWindow(side: .new, start: start, count: upperBound - start)
    }

    /// The lines immediately below a hunk, bounded by the hunk after it or by the end of the file.
    ///
    /// - Parameter newLineCount: How long the new side is, which `FileDiff` carries for exactly
    ///   this — it is what makes "can this hunk expand downwards" answerable without a round trip.
    public static func below(_ hunk: Hunk, before next: Hunk?, endingAt newLineCount: Int) -> LineWindow? {
        let start = max(1, newRange(of: hunk).upperBound)
        let gapEnd = next.map { newRange(of: $0).lowerBound } ?? (newLineCount + 1)
        guard start < gapEnd else { return nil }
        return LineWindow(side: .new, start: start, count: min(step, gapEnd - start))
    }

    /// The hunk with a window of context in front of it.
    public static func expanded(_ hunk: Hunk, above lines: [String]) -> Hunk {
        guard lines.isEmpty == false else { return hunk }
        let new = newRange(of: hunk)
        let old = oldRange(of: hunk)
        let firstNewNumber = new.lowerBound - lines.count
        return spliced(
            hunk,
            newStart: firstNewNumber,
            newEnd: new.upperBound,
            oldStart: old.lowerBound - lines.count,
            oldEnd: old.upperBound,
            lines: context(
                lines,
                fromNewNumber: firstNewNumber,
                // Above a hunk the two sides differ by the distance between their first lines. It
                // is not the same distance below it — a hunk that adds three lines moves the two
                // sides three further apart on the way out than on the way in.
                offsetToOld: old.lowerBound - new.lowerBound
            ) + hunk.lines
        )
    }

    /// The hunk with a window of context after it.
    public static func expanded(_ hunk: Hunk, below lines: [String]) -> Hunk {
        guard lines.isEmpty == false else { return hunk }
        let new = newRange(of: hunk)
        let old = oldRange(of: hunk)
        return spliced(
            hunk,
            newStart: new.lowerBound,
            newEnd: new.upperBound + lines.count,
            oldStart: old.lowerBound,
            oldEnd: old.upperBound + lines.count,
            lines: hunk.lines + context(
                lines,
                fromNewNumber: max(1, new.upperBound),
                offsetToOld: old.upperBound - new.upperBound
            )
        )
    }

    // MARK: -

    /// The half-open range of new-side lines a hunk covers.
    ///
    /// **A zero count is not an empty range at the line it names.** git writes `+c,0` for a hunk
    /// that adds nothing, where `c` is the last line *before* the change on the new side rather
    /// than the first line of it — so a pure deletion sits between `c` and `c + 1`, and measuring
    /// either window from `c` would hand back a line the hunk is already drawing.
    private static func newRange(of hunk: Hunk) -> Range<Int> {
        hunk.newCount == 0
            ? (hunk.newStart + 1)..<(hunk.newStart + 1)
            : hunk.newStart..<(hunk.newStart + hunk.newCount)
    }

    /// The same for the old side, where `-a,0` is a pure addition.
    private static func oldRange(of hunk: Hunk) -> Range<Int> {
        hunk.oldCount == 0
            ? (hunk.oldStart + 1)..<(hunk.oldStart + 1)
            : hunk.oldStart..<(hunk.oldStart + hunk.oldCount)
    }

    private static func context(
        _ lines: [String],
        fromNewNumber firstNewNumber: Int,
        offsetToOld: Int
    ) -> [DiffLine] {
        lines.enumerated().map { position, text in
            let newNumber = firstNewNumber + position
            // **The Mac's own measurement rather than this client's.** `DisplayWidth` is the one
            // implementation of a judgement both ends depend on, and the parser's comment says why
            // it lives in `Core`: two sides re-deriving it independently is a disagreement waiting
            // to become a row-count error in a scroll that must never reflow.
            let width = DisplayWidth(of: text)
            return DiffLine(
                kind: .context,
                oldNumber: newNumber + offsetToOld,
                newNumber: newNumber,
                text: text,
                displayColumns: width.columns,
                needsMeasurement: width.needsMeasurement,
                segments: nil
            )
        }
    }

    private static func spliced(
        _ hunk: Hunk,
        newStart: Int,
        newEnd: Int,
        oldStart: Int,
        oldEnd: Int,
        lines: [DiffLine]
    ) -> Hunk {
        Hunk(
            index: hunk.index,
            oldStart: oldStart,
            oldCount: oldEnd - oldStart,
            newStart: newStart,
            newCount: newEnd - newStart,
            // Kept, because it is still git's answer to what encloses the change. Expanding the
            // context does not move the change, and re-deriving the heading from lines this client
            // spliced in would be the client inventing a string git owns.
            sectionHeading: hunk.sectionHeading,
            lines: lines
        )
    }
}
