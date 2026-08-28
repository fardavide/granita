import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// A line as it is drawn, and where within it the word diff changed something.
///
/// **The ranges exist because the emphasis moved from the text to the background.** Design §4 first
/// carried a changed run by taking everything around it down to secondary, which spends the text
/// colour — and `SPEC.md` §10 wants that colour for the syntax highlighter. Davide settled it on 28
/// August 2026: the changed words get a background and the text is the lexer's. So the drawn line is
/// one string with the changed runs named by offset, rather than a list of differently coloured
/// pieces.
@Suite("Drawn diff line")
struct DrawnDiffLineTests {

    @Test
    func `given a line the parser paired when it is drawn then the changed run is the only range`() {
        // given
        let line = aLine(text: "let store = Store()", segments: [
            WordSegment(text: "let ", isChanged: false),
            WordSegment(text: "store", isChanged: true),
            WordSegment(text: " = Store()", isChanged: false)
        ])

        // when
        let drawn = DrawnDiffLine.of(line)

        // then — offsets into the drawn string, which is what a background is applied over.
        #expect(drawn.text == "let store = Store()")
        #expect(drawn.changed == [4..<9])
    }

    @Test
    func `given a line with two changed runs when it is drawn then both are named`() {
        // given — a background per run rather than one spanning the gap between them, which would
        // claim the unchanged text in the middle had changed.
        let line = aLine(text: "a = b + c", segments: [
            WordSegment(text: "a", isChanged: true),
            WordSegment(text: " = b + ", isChanged: false),
            WordSegment(text: "c", isChanged: true)
        ])

        // when
        let drawn = DrawnDiffLine.of(line)

        // then
        #expect(drawn.changed == [0..<1, 8..<9])
    }

    @Test
    func `given a line the parser did not pair when it is drawn then nothing is changed within it`() {
        // given — the ordinary case: an addition with no deletion opposite it has no *unchanged*
        // part to be told apart from, so the row tint is the whole of what says it changed.
        let line = aLine(text: "let a = 1", segments: nil)

        // when
        let drawn = DrawnDiffLine.of(line)

        // then
        #expect(drawn.text == "let a = 1")
        #expect(drawn.changed.isEmpty)
    }

    @Test
    func `given a line paired as one whole run when it is drawn then nothing is changed within it`() {
        // given — a single segment means the parser found nothing in common, and backgrounding the
        // whole line would draw a second, stronger copy of the row tint over the row tint.
        let line = aLine(text: "let a = 1", segments: [WordSegment(text: "let a = 1", isChanged: true)])

        // when
        let drawn = DrawnDiffLine.of(line)

        // then
        #expect(drawn.changed.isEmpty)
    }

    // MARK: - The grid

    @Test
    func `given a tab before a changed run when the line is drawn then the run is offset by the spaces`() {
        // given — the range is into the string as *drawn*, so a tab that became four spaces has
        // moved everything after it three columns along.
        let line = aLine(text: "\tstore = x", segments: [
            WordSegment(text: "\t", isChanged: false),
            WordSegment(text: "store", isChanged: true),
            WordSegment(text: " = x", isChanged: false)
        ])

        // when
        let drawn = DrawnDiffLine.of(line)

        // then — four, not one. A range measured against the raw text would have backgrounded the
        // three spaces and the first two letters.
        #expect(drawn.text == "    store = x")
        #expect(drawn.changed == [4..<9])
    }

    @Test
    func `given a tab inside a later run when the line is drawn then it measures from the line's own column`() {
        // given — **the defect that expanding each run from zero produces.** The first run reaches
        // column two, so the tab in the second fills two spaces rather than four.
        let line = aLine(text: "if\ttrue", segments: [
            WordSegment(text: "if", isChanged: false),
            WordSegment(text: "\ttrue", isChanged: true)
        ])

        // when
        let drawn = DrawnDiffLine.of(line)

        // then
        #expect(drawn.text == "if  true")
        #expect(drawn.changed == [2..<8])
    }

    @Test
    func `given a drawn line when it is compared with the whole-line expansion then the two agree`() {
        // given — the property the pieces have to hold: drawing a line in runs must produce the
        // same string as drawing it at once, or the gutter is measuring one line and the code is
        // showing another.
        let text = "\tif\tx { y() }"
        let line = aLine(text: text, segments: [
            WordSegment(text: "\tif", isChanged: false),
            WordSegment(text: "\tx", isChanged: true),
            WordSegment(text: " { y() }", isChanged: false)
        ])

        // when
        let drawn = DrawnDiffLine.of(line)

        // then
        #expect(drawn.text == MonospacedGrid.expandingTabs(in: text))
    }

    @Test
    func `given a wide character in a changed run when the line is drawn then the range counts characters`() {
        // given — the grid counts an ideograph as two columns and a string counts it as one
        // character, and a background is applied over characters. Conflating the two is a
        // highlight that starts a glyph early.
        let line = aLine(text: "let s = \"図形\"", segments: [
            WordSegment(text: "let s = ", isChanged: false),
            WordSegment(text: "\"図形\"", isChanged: true)
        ])

        // when
        let drawn = DrawnDiffLine.of(line)

        // then — eight characters in, and four characters long.
        #expect(drawn.changed == [8..<12])
    }
}

// MARK: -

private func aLine(text: String, segments: [WordSegment]?) -> DiffLine {
    DiffLine(
        kind: .addition,
        oldNumber: nil,
        newNumber: 1,
        text: text,
        displayColumns: DisplayWidth(of: text).columns,
        segments: segments
    )
}
