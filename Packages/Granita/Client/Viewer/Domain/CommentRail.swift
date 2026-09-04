import CoreDiffDomain

/// One stretch of rail, as a hunk draws it.
///
/// Rows rather than points: the view multiplies by its own row height, which is taken from the font
/// and is the one number two stacks in `DiffFileLines` already have to agree on.
public struct CommentRun: Hashable, Sendable, Identifiable {

    /// The first row of this hunk the rail covers.
    public let firstRow: Int

    /// How many rows it covers, always at least one.
    public let rowCount: Int

    /// Whether this is a run being picked out rather than a comment that exists.
    ///
    /// **Square caps pending, round caps saved** — design §7.1 makes it a difference in *shape* so
    /// the state survives a greyscale screenshot and a colourblind reader, which is the same
    /// discipline the `+`/`−` markers were added for.
    public let isPending: Bool

    public init(firstRow: Int, rowCount: Int, isPending: Bool) {
        self.firstRow = firstRow
        self.rowCount = rowCount
        self.isPending = isPending
    }

    /// **The whole run, not its first row.** A saved comment on rows 5–8 and a fresh hold begun on
    /// row 5 are two runs starting in the same place; keyed on `firstRow` alone they collided in the
    /// `ForEach` that draws them, SwiftUI kept one, and which one it kept was undefined — so the
    /// square-capped feedback for the hold sometimes did not appear at all.
    public var id: Self { self }
}

/// Which stretches of rail a hunk draws.
///
/// **A run is clipped to the hunk that draws it, and a run spanning two hunks becomes two.** A file
/// is not one view: `DiffFileContent` lays out one `DiffFileLines` per hunk with torn expander rows
/// between them, so there is no single coordinate space a rail could span. Clipping here is what lets
/// each hunk draw its own part with no knowledge of the others — and it is also what makes the rail
/// disappear correctly from the half of a run whose hunk has scrolled away.
public enum CommentRail {

    /// The runs this hunk draws, in row order.
    ///
    /// **Every anchor is resolved against the whole file rather than against the hunk**, because both
    /// ends of a run may be in other hunks — a comment on lines 41 to 44 where a hunk boundary falls
    /// at 42 has neither end in the second hunk and still has to draw there.
    ///
    /// A comment whose ends no longer resolve draws nothing at all. That is design §7.3's stale case,
    /// and it gets a 44pt amber row under the file's header instead: it has no rows, so it can have
    /// no rail.
    public static func runs(
        of hunk: Hunk,
        in diff: FileDiff,
        comments: [ReviewComment],
        pending: PendingComment?
    ) -> [CommentRun] {
        let all = diff.hunks.flatMap(\.lines)
        guard let offset = offsetOfHunk(hunk, in: diff) else { return [] }
        let saved = comments
            .filter { $0.anchor.file == diff.file.id }
            .compactMap { span(of: $0.anchor.first, to: $0.anchor.last, in: all) }
            .map { (span: $0, isPending: false) }
        let held = pending.flatMap { pending -> (span: ClosedRange<Int>, isPending: Bool)? in
            guard pending.file == diff.file.id,
                  let span = span(of: pending.from, to: pending.to, in: all) else { return nil }
            return (span, true)
        }
        return (saved + [held].compactMap { $0 })
            .compactMap { clipped($0.span, toHunkAt: offset, ofLength: hunk.lines.count, isPending: $0.isPending) }
            // A total key rather than the first row alone: `sorted` is not stable, so two runs
            // starting on one row would otherwise draw in whichever order the comparison happened to
            // settle on, and the answer would change between two frames of the same screen.
            .sorted { ($0.firstRow, $0.rowCount, $0.isPending ? 1 : 0) < ($1.firstRow, $1.rowCount, $1.isPending ? 1 : 0) }
    }

    /// Where this hunk's rows begin among the file's own.
    ///
    /// Found by identity rather than by index arithmetic: expansion replaces a hunk with a wider one
    /// carrying the same `index`, so the count of rows before it moves whenever anything above it
    /// grows.
    private static func offsetOfHunk(_ hunk: Hunk, in diff: FileDiff) -> Int? {
        guard let position = diff.hunks.firstIndex(where: { $0.index == hunk.index }) else { return nil }
        return diff.hunks[..<position].reduce(0) { $0 + $1.lines.count }
    }

    private static func span(
        of first: DiffLinePosition,
        to last: DiffLinePosition,
        in all: [DiffLine]
    ) -> ClosedRange<Int>? {
        guard let start = all.firstIndex(where: { DiffLinePosition.of($0) == first }),
              let end = all.firstIndex(where: { DiffLinePosition.of($0) == last }) else {
            return nil
        }
        return min(start, end)...max(start, end)
    }

    /// The part of a file-wide span that falls inside one hunk, in that hunk's own row numbers.
    private static func clipped(
        _ span: ClosedRange<Int>,
        toHunkAt offset: Int,
        ofLength length: Int,
        isPending: Bool
    ) -> CommentRun? {
        let first = max(span.lowerBound, offset)
        let last = min(span.upperBound, offset + length - 1)
        guard first <= last else { return nil }
        return CommentRun(firstRow: first - offset, rowCount: last - first + 1, isPending: isPending)
    }
}
