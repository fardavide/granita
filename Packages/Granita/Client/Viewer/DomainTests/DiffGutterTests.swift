import Foundation
import Testing

@testable import ClientViewerDomain

/// Design §4's arithmetic, which is the section's own headline: at 390pt one column leaves 51
/// characters of code and two leave 41, and 41 is a keyhole rather than a diff viewer.
///
/// It is asserted here rather than left in prose because the widths decide how much code a phone
/// shows, and the numbers in that section were measured against SF Mono at one size.
///
/// **Compared with a tolerance, and that is not laziness.** These are sums of a point size times
/// six tenths, so three figures' worth is `19.799999999999997` and four is `26.400000000000002`; an
/// exact comparison passes or fails on which of the two a given expression happens to accumulate,
/// which is a test about IEEE 754 rather than about a gutter. A tenth of a thousandth of a point is
/// far below anything a screen can draw and far above anything the arithmetic can drift.
@Suite("Diff gutter")
struct DiffGutterTests {

    @Test
    func `given a four figure file when its column is measured then it is design 4's own 39 points`() {
        // given - when
        let width = DiffGutter.columnWidth(forHighestLineNumber: 1_204, atPointSize: 11)

        // then — 4pt of leading inset, four characters at 6.6, and 9pt of trailing space.
        #expect(isClose(width, 39.4))
    }

    @Test
    func `given a short file when its column is measured then it gives the code the difference`() {
        // given — "a 200-line file gets a 3-digit gutter and 8 more characters of code", which is
        // why this is per file rather than one width for the whole scroll.
        // when
        let width = DiffGutter.columnWidth(forHighestLineNumber: 200, atPointSize: 11)

        // then — 32.8 against the four-figure file's 39.4, which is one character of code back.
        #expect(isClose(width, 32.8))
    }

    @Test
    func `given a file with no lines when its column is measured then it still holds one figure`() {
        // given — an empty new side is a deleted file, whose new column is blank on every row. A
        // zero-width gutter would put the first character of code against the edge on the one row
        // kind that has nothing to align to.
        // when
        let width = DiffGutter.columnWidth(forHighestLineNumber: 0, atPointSize: 11)

        // then
        #expect(isClose(width, 19.6))
    }

    @Test
    func `given a negative highest line when its column is measured then it is the same as none`() {
        // given — not something a diff produces, and the alternative to answering it is a minus
        // sign counted as a figure.
        // when
        let width = DiffGutter.columnWidth(forHighestLineNumber: -3, atPointSize: 11)

        // then
        #expect(isClose(width, 19.6))
    }

    @Test
    func `given a larger code size when a column is measured then the figures grow and the gaps do not`() {
        // given — the code point size is adjustable in settings and independent of Dynamic Type, so
        // a gutter pinned to 11pt would stop lining up with the code beside it at every other size.
        // when
        let width = DiffGutter.columnWidth(forHighestLineNumber: 999, atPointSize: 22)

        // then — 4 + three characters at 13.2 + 9. At 11pt the same file measures 32.8, so the
        // figures doubled and the 13pt of inset and trailing space did not.
        #expect(isClose(width, 52.6))
    }

    @Test
    func `given SF Mono when a character is measured then it advances six tenths of the size`() {
        // given - when - then — the ratio the whole section is derived from, and the one number here
        // that came from measuring a font rather than from arithmetic.
        #expect(isClose(DiffGutter.advanceWidth(atPointSize: 11), 6.6))
    }
}

// MARK: -

private func isClose(_ measured: CGFloat, _ expected: CGFloat) -> Bool {
    abs(measured - expected) < 0.0001
}
