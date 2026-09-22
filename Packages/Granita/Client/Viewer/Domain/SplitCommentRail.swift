import CoreDiffDomain

/// One stretch of comment rail as a *drawn* row range, and which of a block's two cells it sits in.
///
/// **The rail is the one thing on the row that moves when the mode changes, and it moves the
/// shortest possible distance** — design §4.6: into the leading inset of the cell its line is on. A
/// comment is anchored to a `DiffLinePosition`, which already knows its side, so this is a small
/// gain rather than a compromise: unified, the rail sits in one column whichever side the commented
/// line is on, and in a block it can finally say which.
public struct SplitRailSegment: Hashable, Sendable, Identifiable {

    /// The first *drawn* row the rail covers, which is not the line's own index once a block has
    /// folded two lines onto one row.
    public let firstRow: Int

    public let rowCount: Int

    /// Which cell it belongs to, or nothing when the row it is on is full width.
    ///
    /// Optional rather than a third case: outside a block there is one column and the question does
    /// not arise, and a `.both` would be a value the drawing has no answer for.
    public let side: DiffSide?

    public let isPending: Bool

    public init(firstRow: Int, rowCount: Int, side: DiffSide?, isPending: Bool) {
        self.firstRow = firstRow
        self.rowCount = rowCount
        self.side = side
        self.isPending = isPending
    }

    /// The whole segment, for the same reason `CommentRun` keys on the whole run: two segments
    /// starting on one row are two things to draw, and a `ForEach` keyed on the row would keep one
    /// of them and choose which undefinedly.
    public var id: Self { self }
}

/// Where a hunk's comment rails land once the reader has asked for two columns.
///
/// **A run that crosses into a block becomes several segments, and that is correct rather than a
/// compromise.** A comment written over a deletion and the addition replacing it covers two lines
/// that now share a row — so as one rail it would be a single stripe standing for two different
/// sides. Split into a piece per cell, each says exactly which line it is about, and the caps still
/// carry §7.1's pending-or-saved shape at the ends of each piece.
public enum SplitCommentRail {

    /// The segments this hunk draws.
    ///
    /// With the mode off this is today's answer re-expressed: one segment per run, on no side,
    /// covering the same rows. The unified scroll therefore goes through this seam rather than
    /// around it, which is what lets "the mode changes nothing here" be asserted rather than hoped
    /// for.
    public static func segments(
        of runs: [CommentRun],
        in lines: [DiffLine],
        splitting: Bool
    ) -> [SplitRailSegment] {
        guard splitting else {
            return runs.map {
                SplitRailSegment(firstRow: $0.firstRow, rowCount: $0.rowCount, side: nil, isPending: $0.isPending)
            }
        }
        let rowOfLine = SplitDiffRow.rowIndices(of: lines, splitting: true)
        let rows = SplitDiffRow.rows(of: lines, splitting: true)
        return runs.flatMap { run -> [SplitRailSegment] in
            let covered = (run.firstRow..<(run.firstRow + run.rowCount))
                .filter { lines.indices.contains($0) }
                .map { index -> (row: Int, side: DiffSide?) in
                    let row = rowOfLine[index]
                    // A line drawn full width has one column, so the rail has nowhere else to be.
                    guard case .block = rows[row] else { return (row, nil) }
                    return (row, lines[index].kind == .deletion ? .old : .new)
                }
            return coalesced(covered, isPending: run.isPending)
        }
    }

    /// Consecutive rows in the same cell become one segment, so a four-line comment is one rail
    /// rather than four stacked ones with three seams in it.
    private static func coalesced(
        _ covered: [(row: Int, side: DiffSide?)],
        isPending: Bool
    ) -> [SplitRailSegment] {
        var segments: [SplitRailSegment] = []
        for entry in covered {
            if let last = segments.last,
               last.side == entry.side,
               last.firstRow + last.rowCount == entry.row {
                segments.removeLast()
                segments.append(SplitRailSegment(
                    firstRow: last.firstRow,
                    rowCount: last.rowCount + 1,
                    side: last.side,
                    isPending: isPending
                ))
            } else {
                // **Including the same row reached again on the other side**, which is a comment
                // written across a change: its deletion and the addition replacing it are one row
                // and two cells, so they are two segments rather than one longer one. The same row
                // twice on *one* side cannot arise — within a block only old[i] and new[i] land on
                // row i, and they are different sides — so there is no case here for it.
                segments.append(SplitRailSegment(
                    firstRow: entry.row,
                    rowCount: 1,
                    side: entry.side,
                    isPending: isPending
                ))
            }
        }
        return segments
    }
}
