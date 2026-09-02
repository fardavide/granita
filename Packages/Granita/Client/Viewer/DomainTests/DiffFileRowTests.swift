import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Which rows a file's diff draws, which is design §4's expander decided before anything renders.
///
/// **The rule under all of it is that a gap is a row and a row is torn where the lines are missing.**
/// So this suite is mostly about *placement*: the same three lines of code produce a different
/// expander depending on whether there is a hunk above it, below it, both, or neither — and the
/// fourth case draws nothing at all, which §4 calls the state that does not exist.
@Suite("Diff file rows")
struct DiffFileRowTests {

    // MARK: - Where a gap puts itself

    @Test
    func `given a hunk that starts below the first line when the rows are built then the gap above it is torn above`() {
        // given — the diff skipped into line 8, so seven lines are missing and there is nothing
        // above them to reveal from.
        let diff = aDiff(hunks: [aHunk(index: 0, newStart: 8, newCount: 4)], newLineCount: 11)

        // when
        let rows = DiffFileRow.rows(of: diff)

        // then — the count is the whole gap rather than the twenty lines one press opens, because
        // the row says how much is missing before it says anything else.
        #expect(rows.count == 2)
        #expect(rows.first == .gap(.aboveTheFirstHunk(lineCount: 7, heading: aHeading, hunk: 0)))
    }

    @Test
    func `given two hunks with lines between them when the rows are built then the gap is torn both ways`() {
        // given — hunk 0 ends at line 5 and hunk 1 starts at 9, so lines 5 through 8 are missing
        // with a hunk on each side of them.
        let diff = aDiff(
            hunks: [aHunk(index: 0, newStart: 1, newCount: 4), aHunk(index: 1, newStart: 9, newCount: 4)],
            newLineCount: 12
        )

        // when
        let rows = DiffFileRow.rows(of: diff)

        // then — hunk, gap, hunk. Both ends are named, because either can be revealed and the row
        // carries a control for each.
        #expect(rows.count == 3)
        #expect(rows[1] == .gap(.betweenHunks(lineCount: 4, above: 0, below: 1)))
    }

    @Test
    func `given a file that runs on past its last hunk when the rows are built then the gap is torn below`() {
        // given — the hunk draws lines 1 through 4 and the file has 23, so nineteen are missing
        // after it.
        let diff = aDiff(hunks: [aHunk(index: 0, newStart: 1, newCount: 4)], newLineCount: 23)

        // when
        let rows = DiffFileRow.rows(of: diff)

        // then
        #expect(rows.count == 2)
        #expect(rows.last == .gap(.afterTheLastHunk(lineCount: 19, hunk: 0)))
    }

    @Test
    func `given a hunk that covers the whole file when the rows are built then there is no gap at all`() {
        // given — from the first line to the last, which is the ordinary small file.
        let diff = aDiff(hunks: [aHunk(index: 0, newStart: 1, newCount: 4)], newLineCount: 4)

        // when
        let rows = DiffFileRow.rows(of: diff)

        // then — design §4's fourth state, which is that there is none: a row that could never be
        // pressed is a label, and it would sit at the top of most files.
        #expect(rows == [.hunk(diff.hunks[0])])
    }

    @Test
    func `given a file with gaps everywhere when the rows are built then each one is placed on its own`() {
        // given — a diff that skipped into the file, skipped between its hunks, and stopped short of
        // the end. One file, all three placements, in order.
        let diff = aDiff(
            hunks: [aHunk(index: 0, newStart: 8, newCount: 4), aHunk(index: 1, newStart: 30, newCount: 4)],
            newLineCount: 90
        )

        // when
        let rows = DiffFileRow.rows(of: diff)

        // then
        #expect(rows.count == 5)
        #expect(rows[0] == .gap(.aboveTheFirstHunk(lineCount: 7, heading: aHeading, hunk: 0)))
        #expect(rows[2] == .gap(.betweenHunks(lineCount: 18, above: 0, below: 1)))
        #expect(rows[4] == .gap(.afterTheLastHunk(lineCount: 57, hunk: 1)))
    }

    @Test
    func `given a hunk git gave no heading when the rows are built then the gap above it names nothing`() {
        // given — the ordinary case rather than the odd one: git omits the heading whenever nothing
        // encloses the change.
        let diff = aDiff(hunks: [aHunk(index: 0, newStart: 8, newCount: 4, heading: nil)], newLineCount: 11)

        // when
        let rows = DiffFileRow.rows(of: diff)

        // then — the row still exists and still counts. It has nothing to name, which is different
        // from having nothing to do.
        #expect(rows.first == .gap(.aboveTheFirstHunk(lineCount: 7, heading: nil, hunk: 0)))
    }

    @Test
    func `given a file with no hunks at all when the rows are built then nothing is drawn`() {
        // given — a binary file's diff, or one the size guard emptied.
        let diff = aDiff(hunks: [], newLineCount: 0)

        // when
        let rows = DiffFileRow.rows(of: diff)

        // then — no trailing gap either. A file with no hunks has no diff to skip around in.
        #expect(rows.isEmpty)
    }

    // MARK: - What a row is called

    @Test
    func `given the three gaps when they are identified then a gap and the hunk under it do not collide`() {
        // given — the identity a `ForEach` draws one row per, and the collision worth asserting is
        // between a gap and the hunk it sits above: both know the same hunk number.
        let diff = aDiff(
            hunks: [aHunk(index: 0, newStart: 8, newCount: 4), aHunk(index: 1, newStart: 30, newCount: 4)],
            newLineCount: 90
        )

        // when
        let rows = DiffFileRow.rows(of: diff)

        // then
        #expect(Set(rows.map(\.id)).count == rows.count)
        #expect(rows[0].id == .gapAbove(0))
        #expect(rows[1].id == .hunk(0))
        #expect(rows[4].id == .gapBelow(1))
    }

    @Test
    func `given each gap when it is asked how many lines it holds then it answers from whichever case it is`() {
        // given - when - then — read by the row that prints it, and every case has to answer or the
        // count is missing from one of the three.
        #expect(DiffGap.aboveTheFirstHunk(lineCount: 7, heading: nil, hunk: 0).lineCount == 7)
        #expect(DiffGap.betweenHunks(lineCount: 4, above: 0, below: 1).lineCount == 4)
        #expect(DiffGap.afterTheLastHunk(lineCount: 18, hunk: 0).lineCount == 18)
    }
}

// MARK: -

private let aHeading = "func health() async throws(ApiFailure) -> HealthResponse"

private func aHunk(index: Int, newStart: Int, newCount: Int, heading: String? = aHeading) -> Hunk {
    Hunk(
        index: index,
        oldStart: newStart,
        oldCount: newCount,
        newStart: newStart,
        newCount: newCount,
        sectionHeading: heading,
        lines: (0..<newCount).map { offset in
            DiffLine(
                kind: .context,
                oldNumber: newStart + offset,
                newNumber: newStart + offset,
                text: "    let answer = \(offset)",
                displayColumns: 20,
                segments: nil
            )
        }
    )
}

private func aDiff(hunks: [Hunk], newLineCount: Int) -> FileDiff {
    FileDiff(
        file: FileChange(
            id: FileID(rawValue: "the-one-being-read"),
            path: "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift",
            oldPath: nil,
            status: .modified,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 4, deletions: 1),
            contentHash: String(repeating: "c", count: 64),
            estimatedLineCount: newLineCount,
            isViewed: false,
            isTruncated: false,
            language: "swift"
        ),
        hunks: hunks,
        oldLineCount: newLineCount,
        newLineCount: newLineCount,
        isTruncated: false,
        truncationReason: nil
    )
}
