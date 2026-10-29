import Testing

import ClientViewerDomain
import CoreDiffDomain

@Suite("Prepared diff lines")
struct PreparedDiffLinesTests {

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
