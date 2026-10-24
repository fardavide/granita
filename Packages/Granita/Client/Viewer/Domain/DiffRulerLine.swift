import CoreDiffDomain

/// Literal text measured by the hunk's invisible ruler, retaining its rendered weight.
public struct DiffRulerLine: Hashable, Sendable {

    public let text: String
    public let kind: DiffLineKind

    public init(text: String, kind: DiffLineKind) {
        self.text = text
        self.kind = kind
    }

    /// Printable ASCII shares one advance within each monospaced weight. Keep every other line:
    /// fallback fonts, combining characters and controls cannot be ranked by character count.
    public static func representatives(in lines: [DiffRulerLine]) -> [DiffRulerLine] {
        let printable = lines.map { line in
            line.text.unicodeScalars.allSatisfy { (32...126).contains($0.value) }
        }
        let regular = lines.indices
            .filter { printable[$0] && lines[$0].kind != .conflictMarker }
            .max { lines[$0].text.count < lines[$1].text.count }
        let conflict = lines.indices
            .filter { printable[$0] && lines[$0].kind == .conflictMarker }
            .max { lines[$0].text.count < lines[$1].text.count }
        return lines.enumerated().compactMap { index, line in
            printable[index] == false || index == regular || index == conflict ? line : nil
        }
    }
}
