import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

@Suite("Diff ruler line")
struct DiffRulerLineTests {

    @Test
    func `given printable lines in both weights when selecting ruler representatives then the first longest in each weight survives in input order`() {
        // given
        let scenario = Scenario()
        let lines = [
            DiffRulerLine(text: "short", kind: .context),
            DiffRulerLine(text: "<<<<<<< branch", kind: .conflictMarker),
            DiffRulerLine(text: "let longestRegular = 42", kind: .addition),
            DiffRulerLine(text: "let sameLengthCopy = 43", kind: .deletion),
            DiffRulerLine(text: ">>>>>>> branch", kind: .conflictMarker),
            DiffRulerLine(text: "=======", kind: .conflictMarker),
            DiffRulerLine(text: "tail", kind: .noNewlineMarker)
        ]

        // when
        let representatives = scenario.sut.representatives(in: lines)

        // then
        #expect(representatives == [
            DiffRulerLine(text: "<<<<<<< branch", kind: .conflictMarker),
            DiffRulerLine(text: "let longestRegular = 42", kind: .addition)
        ])
    }

    @Test(arguments: [false, true], [false, true])
    func `given lines outside printable ASCII in both weights when selecting ruler representatives then every such line stays in input order`(
        hasRegularAscii: Bool,
        hasConflictAscii: Bool
    ) {
        // given
        let scenario = Scenario()
        var lines = [
            DiffRulerLine(text: "日本語", kind: .context),
            DiffRulerLine(text: "<<<<<<< fée", kind: .conflictMarker)
        ]
        var expected = lines
        if hasRegularAscii {
            lines += [
                DiffRulerLine(text: "short", kind: .deletion),
                DiffRulerLine(text: "let longestRegular = 42", kind: .addition)
            ]
            expected.append(DiffRulerLine(text: "let longestRegular = 42", kind: .addition))
        }
        if hasConflictAscii {
            lines += [
                DiffRulerLine(text: "=======", kind: .conflictMarker),
                DiffRulerLine(text: "<<<<<<< longest branch", kind: .conflictMarker)
            ]
            expected.append(DiffRulerLine(text: "<<<<<<< longest branch", kind: .conflictMarker))
        }
        let trailingLines = [
            DiffRulerLine(text: "é", kind: .addition),
            DiffRulerLine(text: "é", kind: .addition),
            DiffRulerLine(text: "\u{001F}", kind: .deletion),
            DiffRulerLine(text: "\u{007F}", kind: .conflictMarker)
        ]
        lines += trailingLines
        expected += trailingLines

        // when
        let representatives = scenario.sut.representatives(in: lines)

        // then
        #expect(representatives == expected)
    }

    private struct Scenario {
        let sut = DiffRulerLine.self
    }
}
