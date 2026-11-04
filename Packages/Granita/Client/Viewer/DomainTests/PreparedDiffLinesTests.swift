import Testing

import ClientViewerDomain
import CoreDiffDomain

@Suite("Prepared diff lines")
struct PreparedDiffLinesTests {

    @Test(arguments: [
        (raw: " ~", segments: nil, expected: true),
        (raw: "", segments: nil, expected: true),
        (raw: "printable", segments: [], expected: true),
        (raw: "raw", segments: [WordSegment(text: "", isChanged: true)], expected: true),
        (raw: "raw", segments: [WordSegment(text: " ", isChanged: false), WordSegment(text: "~", isChanged: true)], expected: true),
        (raw: "raw", segments: [WordSegment(text: "ASCII", isChanged: true), WordSegment(text: "\t", isChanged: false)], expected: false),
        (raw: "raw", segments: [WordSegment(text: "\n", isChanged: true)], expected: false),
        (raw: "raw", segments: [WordSegment(text: "\u{0000}", isChanged: true)], expected: false),
        (raw: "raw", segments: [WordSegment(text: "\u{007F}", isChanged: true)], expected: false),
        (raw: "raw", segments: [WordSegment(text: "é", isChanged: true)], expected: false),
        (raw: "\t", segments: [WordSegment(text: "ASCII", isChanged: true)], expected: false),
        (raw: "\t", segments: [], expected: false),
        (raw: "\n", segments: nil, expected: false),
        (raw: "\u{0000}", segments: nil, expected: false),
        (raw: "\u{001F}", segments: nil, expected: false),
        (raw: "\u{007F}", segments: nil, expected: false),
        (raw: "é", segments: nil, expected: false),
        (raw: "図", segments: [WordSegment(text: "ASCII", isChanged: false)], expected: false)
    ] as [(raw: String, segments: [WordSegment]?, expected: Bool)])
    func `given raw source and segments when preparing lines then printable ASCII facts preserve source order without normalizing unsupported characters`(
        fixture: (raw: String, segments: [WordSegment]?, expected: Bool)
    ) {
        // given
        let lines = [
            DiffLine(
                kind: .context, oldNumber: 1, newNumber: 1,
                text: "ASCII", displayColumns: 5, segments: nil
            ),
            DiffLine(
                kind: .addition, oldNumber: nil, newNumber: 2,
                text: fixture.raw, displayColumns: fixture.raw.count, segments: fixture.segments
            ),
            DiffLine(
                kind: .context, oldNumber: 3, newNumber: 3,
                text: "図", displayColumns: 2, segments: nil
            )
        ]

        // when
        let prepared = PreparedDiffLines(lines: lines)

        // then
        #expect(prepared.lines == lines)
        #expect(prepared.sourceIsPrintableAscii == [true, fixture.expected, false])
    }

    @Test
    func `given source rows with segmented tabs and Unicode when preparing lines then source order and effective drawing and ruler text stay coherent`() {
        // given
        let lines = [
            DiffLine(
                kind: .addition,
                oldNumber: nil,
                newNumber: 1,
                text: "raw text",
                displayColumns: 8,
                segments: [
                    WordSegment(text: "if", isChanged: false),
                    WordSegment(text: "\ttrue", isChanged: true)
                ]
            ),
            DiffLine(
                kind: .context,
                oldNumber: 2,
                newNumber: 2,
                text: "図",
                displayColumns: 2,
                segments: nil
            )
        ]

        // when
        let prepared = PreparedDiffLines(lines: lines)

        // then
        #expect(prepared.lines == lines)
        #expect(prepared.drawn == [
            DrawnDiffLine(text: "if  true", changed: [2..<8]),
            DrawnDiffLine(text: "図", changed: [])
        ])
        #expect(prepared.ruler == [
            DiffRulerLine(text: "if  true", kind: .addition),
            DiffRulerLine(text: "図", kind: .context)
        ])
    }
}
