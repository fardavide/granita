import CoreGraphics
import Foundation
import SwiftUI

enum DiffTextRunVisibility {
    static func supportsCulling(sourceText: String, highlighting: AttributedString?) -> Bool {
        var source = sourceText
        guard source.withUTF8({ bytes in
            bytes.allSatisfy { (0x20...0x7E).contains($0) }
        }) else { return false }
        guard let highlighting else { return true }
        var highlightedText = String(highlighting.characters)
        guard highlightedText.withUTF8({ bytes in
            bytes.allSatisfy { (0x20...0x7E).contains($0) }
        }) else { return false }
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
