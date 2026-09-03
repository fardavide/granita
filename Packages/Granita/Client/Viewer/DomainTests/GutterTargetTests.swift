import Foundation
import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Which row a thumb landing on the gutter meant.
///
/// **This is the arithmetic behind design §7's answer to the 44pt question, and it is the whole of
/// what makes an 18pt target defensible.** The gutter is not a column of buttons — it is a
/// continuous coordinate, like a scrubber, with one recogniser over the whole strip and the row
/// derived from the touch's `y`. There is no dead space in it and no boundary to land inside, so a
/// miss cannot produce nothing; it can only land one row off, and the composer's range control is
/// what makes that one tap to fix.
///
/// The rules that follow from being a coordinate rather than a control are all here: the touch
/// resolves to the row it is inside, it clamps rather than failing at either end, and a row the
/// gutter draws no figure for is skipped — resolved instead to whichever numbered centre is nearer,
/// so `\ No newline at end of file` can sit inside a run and can never end one.
@Suite("Gutter target")
struct GutterTargetTests {

    // MARK: - Landing on a row

    @Test
    func `given a touch inside a row when it is resolved then it is that row`() {
        // given — 18pt rows, so the third row runs from 36 to 54.
        let lines = numbered(6)

        // when
        let row = GutterTarget.row(at: 40, of: lines, rowHeight: 18)

        // then
        #expect(row == 2)
    }

    @Test
    func `given a touch on a row's own boundary when it is resolved then it is the row below`() {
        // given — 36.0 is the first pixel of the third row rather than the last of the second, which
        // is the same convention every layout in this app uses and the one a reader cannot perceive
        // either way.
        let lines = numbered(6)

        // when
        let row = GutterTarget.row(at: 36, of: lines, rowHeight: 18)

        // then
        #expect(row == 2)
    }

    @Test
    func `given a touch above the first row when it is resolved then it clamps to the first`() {
        // given — a strip is laid out to the pixel and a touch is not. Refusing here would make the
        // top row of every hunk harder to hit than the rest, which is the opposite of what a
        // continuous coordinate is for.
        let lines = numbered(6)

        // when
        let row = GutterTarget.row(at: -4, of: lines, rowHeight: 18)

        // then
        #expect(row == 0)
    }

    @Test
    func `given a touch below the last row when it is resolved then it clamps to the last`() {
        // given
        let lines = numbered(6)

        // when — well past 6 × 18.
        let row = GutterTarget.row(at: 400, of: lines, rowHeight: 18)

        // then
        #expect(row == 5)
    }

    // MARK: - The rows that are not targets

    @Test
    func `given the touch lands on a row with no figure when it is resolved then the nearer numbered row wins`() {
        // given — the marker sits at index 1, so its band is 18 to 36 and its centre is 27. A touch
        // at 31 is past that centre, so the numbered row below is nearer.
        let lines = [
            aLine(kind: .deletion, old: 120, new: nil),
            aLine(kind: .noNewlineMarker, old: nil, new: nil),
            aLine(kind: .addition, old: nil, new: 121)
        ]

        // when
        let row = GutterTarget.row(at: 31, of: lines, rowHeight: 18)

        // then
        #expect(row == 2)
    }

    @Test
    func `given the touch lands high on a row with no figure when it is resolved then the row above wins`() {
        // given — 22 is before the marker's own centre at 27, so the deletion above is nearer.
        let lines = [
            aLine(kind: .deletion, old: 120, new: nil),
            aLine(kind: .noNewlineMarker, old: nil, new: nil),
            aLine(kind: .addition, old: nil, new: 121)
        ]

        // when
        let row = GutterTarget.row(at: 22, of: lines, rowHeight: 18)

        // then
        #expect(row == 0)
    }

    @Test
    func `given two numbered rows equally near when it is resolved then the one above wins`() {
        // given — the marker's own centre, which is exactly 9pt from each neighbour's. Deterministic
        // rather than whichever the comparison happened to reach first: a tie that answers
        // differently on two runs is a target that behaves differently on two taps.
        let lines = [
            aLine(kind: .deletion, old: 120, new: nil),
            aLine(kind: .noNewlineMarker, old: nil, new: nil),
            aLine(kind: .addition, old: nil, new: 121)
        ]

        // when
        let row = GutterTarget.row(at: 27, of: lines, rowHeight: 18)

        // then
        #expect(row == 0)
    }

    @Test
    func `given a run of rows with no figure when it is resolved then it reaches past all of them`() {
        // given — a hunk can carry the no-newline marker on both sides of one change, which is two
        // unnumbered rows together.
        let lines = [
            aLine(kind: .deletion, old: 120, new: nil),
            aLine(kind: .noNewlineMarker, old: nil, new: nil),
            aLine(kind: .noNewlineMarker, old: nil, new: nil),
            aLine(kind: .addition, old: nil, new: 121)
        ]

        // when — inside the second marker, whose centre is 45; the addition's centre is 63 and the
        // deletion's is 9.
        let row = GutterTarget.row(at: 46, of: lines, rowHeight: 18)

        // then
        #expect(row == 3)
    }

    @Test
    func `given a hunk with no numbered row at all when it is resolved then there is no target`() {
        // given — not something the parser produces, and answered rather than assumed away: a strip
        // over rows that can none of them carry a comment must refuse rather than pick one.
        let lines = [
            aLine(kind: .noNewlineMarker, old: nil, new: nil),
            aLine(kind: .noNewlineMarker, old: nil, new: nil)
        ]

        // when - then
        #expect(GutterTarget.row(at: 20, of: lines, rowHeight: 18) == nil)
    }

    @Test
    func `given no rows at all when it is resolved then there is no target`() {
        // given - when - then
        #expect(GutterTarget.row(at: 20, of: [], rowHeight: 18) == nil)
    }

    @Test
    func `given a row height of nothing when it is resolved then there is no target`() {
        // given — a strip whose rows have no height cannot divide a coordinate by one. Unreachable
        // from the screen, where the height comes from the font, and refused rather than dividing.
        let lines = numbered(4)

        // when - then
        #expect(GutterTarget.row(at: 20, of: lines, rowHeight: 0) == nil)
    }

    // MARK: - How wide the strip is

    @Test
    func `given a three-figure file when the strip is measured then it reaches the code's own origin`() {
        // given - when — 4 + 3 × 6.6 + 9 for the figures, then the 12pt marker and the 6pt after it.
        let width = DiffGutter.tapStripWidth(forHighestLineNumber: 420, atPointSize: 11)

        // then — the design's "about 51pt on a three-figure file". It is exactly the code's origin,
        // because the strip is defined as everything to the left of the first character.
        #expect(abs(width - 50.8) < 0.001)
    }

    @Test
    func `given a file of nine lines when the strip is measured then it is still wide enough for a thumb`() {
        // given - when — the narrowest strip any change set can produce.
        let width = DiffGutter.tapStripWidth(forHighestLineNumber: 9, atPointSize: 11)

        // then — the design's "38 on a file with nine lines in it". Under 44 in width as well as in
        // height, which is the whole reason section one argues from continuity rather than from size.
        #expect(abs(width - 37.6) < 0.001)
    }

    @Test
    func `given the iPad's larger code when the strip is measured then it grows with it`() {
        // given - when — 12pt code, where design §7 says the gutter is 44pt wide and the aim easier.
        let width = DiffGutter.tapStripWidth(forHighestLineNumber: 1204, atPointSize: 12)

        // then — 4 + 4 × 7.2 + 9 + 12 + 6.
        #expect(abs(width - 59.8) < 0.001)
    }
}

// MARK: -

private func aLine(kind: DiffLineKind, old: Int?, new: Int?) -> DiffLine {
    DiffLine(kind: kind, oldNumber: old, newNumber: new, text: "", displayColumns: 0, segments: nil)
}

private func numbered(_ count: Int) -> [DiffLine] {
    (1...count).map { aLine(kind: .context, old: $0, new: $0) }
}
