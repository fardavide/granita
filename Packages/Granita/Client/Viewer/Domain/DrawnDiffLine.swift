import CoreDiffDomain

/// One diff line as it is drawn: the text on the grid, and where the word diff changed something.
///
/// **The ranges are into the drawn string, not the raw one.** A tab becomes the spaces that reach
/// the next stop, so every offset after one has moved — and a background applied at a raw offset
/// starts partway through the wrong word.
public struct DrawnDiffLine: Hashable, Sendable {

    /// The line with its tabs expanded, which is the string a text engine is handed.
    public let text: String

    /// The changed runs, as character offsets into `text`.
    ///
    /// Characters rather than columns: a background is applied over the string, and an ideograph is
    /// one character of it and two columns of the grid. The grid's count belongs to the wrap
    /// arithmetic and this one to the drawing, and they are not the same number.
    public let changed: [Range<Int>]

    public init(text: String, changed: [Range<Int>]) {
        self.text = text
        self.changed = changed
    }

    /// The line, split where the parser paired it and put back together on one grid.
    ///
    /// **The emphasis is a background because the text colour is spoken for.** Design §4 originally
    /// carried a changed run by dropping everything around it to secondary, which reads well until
    /// the syntax highlighter arrives and wants the same property — `SPEC.md` §10 has always
    /// specified "a stronger background on the changed spans over the line level add/remove
    /// background", and Davide settled the collision back to the specification on 28 August 2026.
    /// Recorded in `.claude/docs/decisions.md`.
    public static func of(_ line: DiffLine) -> DrawnDiffLine {
        guard let segments = line.segments, segments.count > 1 else {
            // Either the parser paired this line with nothing, or it paired it as one whole run —
            // and a run covering the line has no unchanged part to be told apart from, so
            // backgrounding it would draw a second, stronger copy of the row tint over the row tint.
            return DrawnDiffLine(text: MonospacedGrid.expandingTabs(in: line.text), changed: [])
        }
        var text = ""
        var changed: [Range<Int>] = []
        var columns = 0
        for segment in segments {
            // The column travels between the runs, because a tab stop is a property of the line and
            // not of the piece being drawn. Expanded from zero, a tab in a later run reaches a whole
            // stop and pushes the rest of the line out of the grid the gutter was measured against.
            let piece = MonospacedGrid.expandingTabs(in: segment.text, startingAtColumn: columns)
            let start = text.count
            text += piece.text
            columns = piece.columns
            if segment.isChanged {
                changed.append(start..<text.count)
            }
        }
        return DrawnDiffLine(text: text, changed: changed)
    }
}
