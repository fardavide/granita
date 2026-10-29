import CoreDiffDomain

public struct PreparedDiffLines: Hashable, Sendable {
    public let lines: [DiffLine]
    public let drawn: [DrawnDiffLine]
    public let ruler: [DiffRulerLine]

    public init(lines: [DiffLine]) {
        self.lines = lines
        let drawn = lines.map { DrawnDiffLine.of($0) }
        self.drawn = drawn
        ruler = DiffRulerLine.representatives(in: zip(lines, drawn).map { line, drawn in
            DiffRulerLine(text: drawn.text, kind: line.kind)
        })
    }
}
