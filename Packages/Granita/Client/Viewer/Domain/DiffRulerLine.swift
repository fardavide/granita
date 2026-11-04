import Foundation

import CoreDiffDomain

/// Literal text measured by the hunk's invisible ruler, retaining its rendered weight.
public struct DiffRulerLine: Hashable, Sendable {

    public let text: String
    public let kind: DiffLineKind

    private static let nonPrintableAscii = CharacterSet(charactersIn: "\u{20}"..."\u{7E}").inverted

    public init(text: String, kind: DiffLineKind) {
        self.text = text
        self.kind = kind
    }

    /// Printable ASCII shares one advance within each monospaced weight. Keep every other line:
    /// fallback fonts, combining characters and controls cannot be ranked by character count.
    public static func representatives(in lines: [DiffRulerLine]) -> [DiffRulerLine] {
        let printable = lines.map { line in
            line.text.rangeOfCharacter(from: nonPrintableAscii) == nil
        }
        let regular = lines.indices
            .filter { printable[$0] && lines[$0].kind != .conflictMarker }
            .max { lines[$0].text.utf8.count < lines[$1].text.utf8.count }
        let conflict = lines.indices
            .filter { printable[$0] && lines[$0].kind == .conflictMarker }
            .max { lines[$0].text.utf8.count < lines[$1].text.utf8.count }
        return lines.enumerated().compactMap { index, line in
            printable[index] == false || index == regular || index == conflict ? line : nil
        }
    }
}
