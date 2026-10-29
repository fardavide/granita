import CoreGraphics
import Foundation
import SwiftUI

enum DiffTextRunVisibility {
    private static let nonPrintableAscii = CharacterSet(charactersIn: "\u{20}"..."\u{7E}").inverted

    static func supportsCulling(sourceText: String, highlighting: AttributedString?) -> Bool {
        guard sourceText.rangeOfCharacter(from: nonPrintableAscii) == nil else { return false }
        guard let highlighting else { return true }
        let highlightedText = String(highlighting.characters)
        guard highlightedText.rangeOfCharacter(from: nonPrintableAscii) == nil else { return false }
        return highlighting.runs.allSatisfy { run in
            var foregroundOnly = AttributeContainer()
            foregroundOnly.foregroundColor = run.foregroundColor
            return run.attributes == foregroundOnly
        }
    }

    static func shouldDraw(runBounds: CGRect, viewport: CGRect, fontGlyphBounds: CGRect) -> Bool {
        guard [runBounds, viewport, fontGlyphBounds].allSatisfy({
            $0.isNull == false && $0.isInfinite == false && $0.minX.isFinite && $0.maxX.isFinite
        }) else { return true }
        let overhang = max(abs(fontGlyphBounds.minX), abs(fontGlyphBounds.maxX))
        return runBounds.maxX + overhang >= viewport.minX && runBounds.minX - overhang <= viewport.maxX
    }
}
