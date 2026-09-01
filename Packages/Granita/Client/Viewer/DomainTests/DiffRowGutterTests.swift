import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Which figure a row shows, and which glyph stands beside it.
///
/// **This is the correctness bug the diff design review opened with.** Until it, the gutter held the
/// new-side number and nothing else, so a deletion — which has no new-side number — drew an empty
/// column. A reader who wanted to say "line 6 is wrong" had nothing to point at on the one row kind
/// that says something was removed. Every row in a diff carries a number now.
///
/// **And the marker is what makes one column honest.** `design.md` §4 rejected a single interleaved
/// column by name — "it looks like one sequence and is two, so scanning it produces wrong line
/// numbers with total confidence" — and that rejection assumed nothing else on the row said which
/// side you were reading. The `+`/`−` column says it, so the objection does not survive. Davide
/// adopted the review's rule 1 and rule 2 together on 1 September 2026, and they only work together.
@Suite("Diff row gutter")
struct DiffRowGutterTests {

    @Test
    func `given a deletion when its figure is chosen then it is the old side's`() {
        // given — the row this whole rule exists for. It has no new-side number, and before the
        // review it therefore had no number at all.
        let line = aLine(kind: .deletion, oldNumber: 6, newNumber: nil)

        // when - then
        #expect(DiffGutter.number(of: line) == 6)
    }

    @Test
    func `given an addition when its figure is chosen then it is the new side's`() {
        // given
        let line = aLine(kind: .addition, oldNumber: nil, newNumber: 6)

        // when - then
        #expect(DiffGutter.number(of: line) == 6)
    }

    @Test
    func `given a context line when its figure is chosen then it is the new side's`() {
        // given — context exists on both sides, and the new side is the file as it is now, which is
        // the file the reader has open on their Mac.
        let line = aLine(kind: .context, oldNumber: 4, newNumber: 7)

        // when - then
        #expect(DiffGutter.number(of: line) == 7)
    }

    @Test
    func `given a no newline marker when its figure is chosen then it has none`() {
        // given — git's own annotation rather than a line of the file, so numbering it would claim
        // the file has a line it does not.
        let line = aLine(kind: .noNewlineMarker, oldNumber: nil, newNumber: nil)

        // when - then
        #expect(DiffGutter.number(of: line) == nil)
    }

    @Test
    func `given a conflict marker on both sides when its figure is chosen then it is the new side's`() {
        // given — **it is a real line of the working copy.** The parser resolves the kind from the
        // text but takes the numbers from the diff prefix the line arrived with, so a `<<<<<<<` that
        // came through as a context line carries both. Blanking these would put the empty gutter
        // back on the rows a reader most needs to point at.
        let line = aLine(kind: .conflictMarker, oldNumber: 62, newNumber: 62)

        // when - then
        #expect(DiffGutter.number(of: line) == 62)
    }

    @Test
    func `given a conflict marker that arrived as an addition when its figure is chosen then it is the new side's`() {
        // given — the `=======` and `>>>>>>>` of a resolved side arrive with a `+` prefix.
        let line = aLine(kind: .conflictMarker, oldNumber: nil, newNumber: 65)

        // when - then
        #expect(DiffGutter.number(of: line) == 65)
    }

    @Test
    func `given a conflict marker that arrived as a deletion when its figure is chosen then it is the old side's`() {
        // given — the one case where falling back to the other side is right rather than wrong: the
        // line exists, and the only number it has is the old one.
        let line = aLine(kind: .conflictMarker, oldNumber: 64, newNumber: nil)

        // when - then
        #expect(DiffGutter.number(of: line) == 64)
    }

    @Test
    func `given a deletion with no old number when its figure is chosen then it has none rather than the new one`() {
        // given — not something the parser produces, and the alternative is a row silently falling
        // back to the other side's number, which is the exact confusion one column has to avoid.
        let line = aLine(kind: .deletion, oldNumber: nil, newNumber: 9)

        // when - then
        #expect(DiffGutter.number(of: line) == nil)
    }

    @Test
    func `given an addition when its marker is chosen then it is a plus`() {
        // given - when - then
        #expect(DiffGutter.marker(of: aLine(kind: .addition, oldNumber: nil, newNumber: 1)) == .added)
    }

    @Test
    func `given a deletion when its marker is chosen then it is a minus`() {
        // given - when - then
        #expect(DiffGutter.marker(of: aLine(kind: .deletion, oldNumber: 1, newNumber: nil)) == .removed)
    }

    @Test
    func `given a context line when its marker is chosen then it has none`() {
        // given — the row that must stay quiet: four rows in five are context, and a glyph on each
        // one is a column of noise the eye has to filter before it can find the two that matter.
        #expect(DiffGutter.marker(of: aLine(kind: .context, oldNumber: 1, newNumber: 1)) == .unchanged)
    }

    @Test
    func `given a no newline marker when its marker is chosen then it has none`() {
        // given — neither added nor removed, and the no-`default:` rule is what forces this to be
        // answered rather than defaulted into a plus.
        #expect(DiffGutter.marker(of: aLine(kind: .noNewlineMarker, oldNumber: nil, newNumber: nil)) == .unchanged)
    }

    @Test
    func `given a conflict marker when its marker is chosen then it has none`() {
        // given — a conflict marker is neither side of the comparison; the row tint is what makes it
        // findable, and it is the one tint drawn at twice strength.
        #expect(DiffGutter.marker(of: aLine(kind: .conflictMarker, oldNumber: nil, newNumber: nil)) == .unchanged)
    }
}

// MARK: -

private func aLine(kind: DiffLineKind, oldNumber: Int?, newNumber: Int?) -> DiffLine {
    DiffLine(
        kind: kind,
        oldNumber: oldNumber,
        newNumber: newNumber,
        text: "",
        displayColumns: 0,
        segments: nil
    )
}
