import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Which rows a hunk draws when the reader has asked for two columns, which is design §4.1's call 1
/// decided before anything renders.
///
/// **The rule under all of it is that the unit is the run and not the file.** So most of this suite
/// is about what *does not* split: context, a change with only one side, a conflict marker, git's
/// no-newline annotation. Each of those is the same full-width row it is today, and the split is
/// spent only where two sides exist to compare.
@Suite("Split diff rows")
struct SplitDiffRowTests {

    // MARK: - What splits

    @Test
    func `given deletions immediately followed by additions when the rows are built then they face each other`() {
        // given — the re-indent Davide asked for: three lines moved right, which the parser sees as
        // three deletions and then three additions.
        let lines = [
            aContextLine(95),
            aDeletion(96), aDeletion(97), aDeletion(98),
            anAddition(96), anAddition(97), anAddition(98),
            aContextLine(99)
        ]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: true)

        // then — six rows became three, and the context either side never moved.
        #expect(rows.count == 5)
        #expect(rows[0] == .full(lines[0]))
        #expect(rows[1] == .block(old: lines[1], new: lines[4]))
        #expect(rows[2] == .block(old: lines[2], new: lines[5]))
        #expect(rows[3] == .block(old: lines[3], new: lines[6]))
        #expect(rows[4] == .full(lines[7]))
    }

    @Test
    func `given a run of d deletions against a additions when the rows are counted then there are max of the two`() {
        // given — the height arithmetic the anchor and the reserved estimate both read, stated as
        // its own case because it is the number every offset in the document moves by.
        let lines = [aDeletion(1), aDeletion(2), aDeletion(3), anAddition(1), anAddition(2)]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: true)

        // then — three, not five. Unified the same run is `d + a`.
        #expect(rows.count == 3)
        #expect(SplitDiffRow.rows(of: lines, splitting: false).count == 5)
    }

    @Test
    func `given an old side that outruns the new when the rows are built then its tail faces nothing`() {
        // given — five lines cut down to two, which is the unbalanced run design §4.1's call 2 draws
        // as an empty cell rather than as a tinted one.
        let lines = [
            aDeletion(10), aDeletion(11), aDeletion(12),
            anAddition(10)
        ]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: true)

        // then — the new side is absent rather than blank, so the card shows through it.
        #expect(rows.count == 3)
        #expect(rows[0] == .block(old: lines[0], new: lines[3]))
        #expect(rows[1] == .block(old: lines[1], new: nil))
        #expect(rows[2] == .block(old: lines[2], new: nil))
    }

    @Test
    func `given a new side that outruns the old when the rows are built then its tail faces nothing`() {
        // given — the same shape the other way up, because the empty cell has to work on both sides
        // and a rule written for one of them is a rule that was never tested.
        let lines = [
            aDeletion(10),
            anAddition(10), anAddition(11), anAddition(12)
        ]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: true)

        // then
        #expect(rows.count == 3)
        #expect(rows[0] == .block(old: lines[0], new: lines[1]))
        #expect(rows[1] == .block(old: nil, new: lines[2]))
        #expect(rows[2] == .block(old: nil, new: lines[3]))
    }

    @Test
    func `given two separate runs in one hunk when the rows are built then each becomes its own block`() {
        // given — context between them, which is what makes them two runs rather than one.
        let lines = [
            aDeletion(1), anAddition(1),
            aContextLine(2),
            aDeletion(3), anAddition(3)
        ]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: true)

        // then
        #expect(rows == [
            .block(old: lines[0], new: lines[1]),
            .full(lines[2]),
            .block(old: lines[3], new: lines[4])
        ])
    }

    // MARK: - What does not split

    @Test
    func `given a file that is only context when the rows are built then every row keeps its full width`() {
        // given — four rows in five of an ordinary change set, and the reason the whole file is not
        // the unit: context is the same string twice, so drawing it twice asks the reader to check.
        let lines = [aContextLine(1), aContextLine(2), aContextLine(3)]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: true)

        // then
        #expect(rows == lines.map(SplitDiffRow.full))
    }

    @Test
    func `given deletions with nothing after them when the rows are built then they keep their full width`() {
        // given — a file that is all deletions, which has no second side to put anywhere.
        let lines = [aDeletion(1), aDeletion(2), aContextLine(3)]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: true)

        // then — design §4.1: the blast radius of this feature is a run, and there is no run here.
        #expect(rows == lines.map(SplitDiffRow.full))
    }

    @Test
    func `given additions with nothing before them when the rows are built then they keep their full width`() {
        // given — a new file, which is the change set the toggle can do nothing to.
        let lines = [aContextLine(1), anAddition(2), anAddition(3)]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: true)

        // then
        #expect(rows == lines.map(SplitDiffRow.full))
    }

    @Test
    func `given a conflict marker between the two sides when the rows are built then nothing pairs across it`() {
        // given — `<<<<<<< HEAD` arrives as an ordinary diff line with its own kind, and it is
        // neither side of the comparison. A run that paired across one would face a deletion with a
        // marker's text.
        let lines = [aDeletion(1), aConflictMarker(2), anAddition(3)]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: true)

        // then
        #expect(rows == lines.map(SplitDiffRow.full))
    }

    @Test
    func `given git's no newline annotation inside a run when the rows are built then the run ends at it`() {
        // given — the one place this diverges from `WordDiff`, which looks *past* the annotation so
        // that a file with no trailing newline still gets its words compared. Two columns cannot: the
        // annotation is not a line of the file, so it has no side to be drawn on, and reordering it
        // out of the block would put it somewhere it did not come from.
        let lines = [aDeletion(1), aNoNewlineMarker(), anAddition(1), aNoNewlineMarker()]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: true)

        // then — unified, and the row order is the order the parser produced.
        #expect(rows == lines.map(SplitDiffRow.full))
    }

    // MARK: - The mode itself

    @Test
    func `given the reader has not asked for two columns when the rows are built then nothing splits`() {
        // given — the same run that splits above, with the mode off.
        let lines = [aDeletion(96), anAddition(96)]

        // when
        let rows = SplitDiffRow.rows(of: lines, splitting: false)

        // then — one row per line, which is what every measurement outside this type still assumes.
        #expect(rows == lines.map(SplitDiffRow.full))
    }

    @Test
    func `given a block row when it is asked for its sides then each one answers for the cell it is`() {
        // given - when - then — read by the view to decide whether to draw a cell at all, and by the
        // gutter to decide which figure goes in it.
        let deletion = aDeletion(1)
        let addition = anAddition(1)
        #expect(SplitDiffRow.block(old: deletion, new: addition).line(on: .old) == deletion)
        #expect(SplitDiffRow.block(old: deletion, new: addition).line(on: .new) == addition)
        #expect(SplitDiffRow.block(old: deletion, new: nil).line(on: .new) == nil)
        // A full row answers with itself on both sides, because it *is* both sides — which is what
        // lets the gutter's target arithmetic stay one rule rather than two.
        #expect(SplitDiffRow.full(deletion).line(on: .old) == deletion)
        #expect(SplitDiffRow.full(deletion).line(on: .new) == deletion)
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

private func aConflictMarker(_ number: Int) -> DiffLine {
    DiffLine(
        kind: .conflictMarker,
        oldNumber: number,
        newNumber: number,
        text: "<<<<<<< HEAD",
        displayColumns: 12,
        segments: nil
    )
}

private func aNoNewlineMarker() -> DiffLine {
    DiffLine(
        kind: .noNewlineMarker,
        oldNumber: nil,
        newNumber: nil,
        text: "\\ No newline at end of file",
        displayColumns: 27,
        segments: nil
    )
}
