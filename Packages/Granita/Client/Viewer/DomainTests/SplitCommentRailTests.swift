import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Where a comment's rail lands once two lines share a row, which is design §4.6's one moving part.
///
/// **The case worth the suite is a comment written across a change.** Its two ends are a deletion
/// and the addition replacing it — one row, two cells — and a rail that stayed one stripe would be
/// standing for both sides at once.
@Suite("Split comment rail")
struct SplitCommentRailTests {

    @Test
    func `given the mode is off when the segments are built then they are the runs unchanged`() {
        // given — the seam the unified scroll goes through, so that "nothing moved" is asserted
        // rather than assumed.
        let lines = [aDeletion(96), anAddition(96)]
        let runs = [CommentRun(firstRow: 0, rowCount: 2, isPending: false)]

        // when
        let segments = SplitCommentRail.segments(of: runs, in: lines, splitting: false)

        // then — one column, so no side, and the same rows.
        #expect(segments == [SplitRailSegment(firstRow: 0, rowCount: 2, side: nil, isPending: false)])
    }

    @Test
    func `given a comment across a change when the segments are built then each cell gets its own`() {
        // given — a run over the deletion and the addition that replaced it. Split, those are one
        // row and two cells.
        let lines = [aDeletion(96), anAddition(96)]
        let runs = [CommentRun(firstRow: 0, rowCount: 2, isPending: false)]

        // when
        let segments = SplitCommentRail.segments(of: runs, in: lines, splitting: true)

        // then — two segments on one row, one per side, rather than one stripe meaning both.
        #expect(segments == [
            SplitRailSegment(firstRow: 0, rowCount: 1, side: .old, isPending: false),
            SplitRailSegment(firstRow: 0, rowCount: 1, side: .new, isPending: false)
        ])
    }

    @Test
    func `given a comment down one side of a block when the segments are built then it is one rail`() {
        // given — three deletions commented on, against three additions. The rail is a run down the
        // old cell and it should read as one stripe rather than three with seams in it.
        let lines = [
            aDeletion(96), aDeletion(97), aDeletion(98),
            anAddition(96), anAddition(97), anAddition(98)
        ]
        let runs = [CommentRun(firstRow: 0, rowCount: 3, isPending: false)]

        // when
        let segments = SplitCommentRail.segments(of: runs, in: lines, splitting: true)

        // then
        #expect(segments == [SplitRailSegment(firstRow: 0, rowCount: 3, side: .old, isPending: false)])
    }

    @Test
    func `given a comment on context above a block when the segments are built then it stays full width`() {
        // given — the ordinary comment, which is on code that did not change.
        let lines = [aContextLine(94), aContextLine(95), aDeletion(96), anAddition(96)]
        let runs = [CommentRun(firstRow: 0, rowCount: 2, isPending: false)]

        // when
        let segments = SplitCommentRail.segments(of: runs, in: lines, splitting: true)

        // then — no side, because the rows it covers have only one column.
        #expect(segments == [SplitRailSegment(firstRow: 0, rowCount: 2, side: nil, isPending: false)])
    }

    @Test
    func `given a comment that runs from context into a block when the segments are built then it breaks at the boundary`() {
        // given — two context lines and then the deletion under them, which is the run a reader
        // picks out by holding across a change.
        let lines = [aContextLine(94), aContextLine(95), aDeletion(96), anAddition(96)]
        let runs = [CommentRun(firstRow: 0, rowCount: 3, isPending: true)]

        // when
        let segments = SplitCommentRail.segments(of: runs, in: lines, splitting: true)

        // then — the full-width part, then the part inside the old cell. Both keep the pending shape.
        #expect(segments == [
            SplitRailSegment(firstRow: 0, rowCount: 2, side: nil, isPending: true),
            SplitRailSegment(firstRow: 2, rowCount: 1, side: .old, isPending: true)
        ])
    }

    @Test
    func `given a run whose rows are past the end of the hunk when the segments are built then nothing traps`() {
        // given — a run clipped against a hunk that has since shrunk, which `CommentRail` resolves
        // against the file and this type is handed after the fact.
        let lines = [aDeletion(96), anAddition(96)]
        let runs = [CommentRun(firstRow: 1, rowCount: 8, isPending: false)]

        // when
        let segments = SplitCommentRail.segments(of: runs, in: lines, splitting: true)

        // then — only the rows that exist.
        #expect(segments == [SplitRailSegment(firstRow: 0, rowCount: 1, side: .new, isPending: false)])
    }
}

// MARK: -

private func aContextLine(_ number: Int) -> DiffLine {
    DiffLine(
        kind: .context,
        oldNumber: number,
        newNumber: number,
        text: "    let answer = \(number)",
        displayColumns: 20,
        segments: nil
    )
}

private func aDeletion(_ number: Int) -> DiffLine {
    DiffLine(
        kind: .deletion,
        oldNumber: number,
        newNumber: nil,
        text: "    let trust = try await verify(certificate)",
        displayColumns: 45,
        segments: nil
    )
}

private func anAddition(_ number: Int) -> DiffLine {
    DiffLine(
        kind: .addition,
        oldNumber: nil,
        newNumber: number,
        text: "        let trust = try await verify(certificate)",
        displayColumns: 49,
        segments: nil
    )
}
