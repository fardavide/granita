import Foundation

import CoreDiffDomain

public struct PreparedDiffLines: Hashable, Sendable {
    public let lines: [DiffLine]
    public let drawn: [DrawnDiffLine]
    public let ruler: [DiffRulerLine]

    /// True only when the original source and every supplied segment contain U+0020...U+007E.
    public let sourceIsPrintableAscii: [Bool]

    private static let nonPrintableAscii = CharacterSet(charactersIn: "\u{20}"..."\u{7E}").inverted

    public init(lines: [DiffLine]) {
        self.lines = lines
        sourceIsPrintableAscii = lines.map { line in
            line.text.rangeOfCharacter(from: Self.nonPrintableAscii) == nil
                && line.segments?.allSatisfy({ $0.text.rangeOfCharacter(from: Self.nonPrintableAscii) == nil }) != false
        }
        let drawn = lines.map { DrawnDiffLine.of($0) }
        self.drawn = drawn
        ruler = DiffRulerLine.representatives(in: zip(lines, drawn).map { line, drawn in
            DiffRulerLine(text: drawn.text, kind: line.kind)
        })
    }
}
