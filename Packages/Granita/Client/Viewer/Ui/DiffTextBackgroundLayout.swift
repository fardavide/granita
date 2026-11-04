import CoreGraphics
import CoreText
import Foundation

struct DiffTextBackgroundLayout {
    private let font: CTFont
    private let line: CTLine
    private let fontGlyphBounds: CGRect
    private let glyphPositions: [CGPoint]
    private let text: String

    init(text: String, font: CTFont) {
        self.font = font
        self.text = text
        line = CTLineCreateWithAttributedString(NSAttributedString(
            string: text,
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
        ) as CFAttributedString)
        fontGlyphBounds = CTFontGetBoundingBox(font)
        glyphPositions = Self.glyphPositions(in: line, text: text, font: font)
    }

    func shouldApplyBackground(in range: Range<Int>, viewport: CGRect) -> Bool {
        let start = offset(at: range.lowerBound)
        let end = offset(at: range.upperBound)
        return DiffTextRunVisibility.shouldDraw(
            runBounds: CGRect(x: min(start, end), y: 0, width: abs(end - start), height: 0),
            viewport: viewport,
            fontGlyphBounds: fontGlyphBounds
        )
    }

    func visibleRanges(in ranges: [Range<Int>], viewport: CGRect) -> [Range<Int>] {
        guard [viewport, fontGlyphBounds].allSatisfy({
            $0.isNull == false && $0.isInfinite == false && $0.minX.isFinite && $0.maxX.isFinite
        }) else {
            return ranges
        }
        let overhang = max(abs(fontGlyphBounds.minX), abs(fontGlyphBounds.maxX))
        var lower = 0
        var upper = ranges.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            let end = offset(at: ranges[middle].upperBound)
            guard end.isFinite else { return ranges }
            if end + overhang < viewport.minX {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        let first = lower
        upper = ranges.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            let start = offset(at: ranges[middle].lowerBound)
            guard start.isFinite else { return ranges }
            if start - overhang > viewport.maxX {
                upper = middle
            } else {
                lower = middle + 1
            }
        }
        return ranges[first..<lower].filter { shouldApplyBackground(in: $0, viewport: viewport) }
    }

    func visibleText(in text: String, viewport: CGRect) -> String {
        switch visibleWindow(in: text, viewport: viewport) {
        case .original:
            return text
        case .window(_, let visible):
            return visible
        }
    }

    func visibleText(in attributed: AttributedString, viewport: CGRect) -> AttributedString {
        guard glyphPositions.isEmpty == false else { return attributed }
        switch visibleWindow(in: String(attributed.characters), viewport: viewport) {
        case .original:
            return attributed
        case .window(let range, _):
            let characters = attributed.characters
            let start = characters.index(characters.startIndex, offsetBy: range.lowerBound)
            let end = characters.index(start, offsetBy: range.count)
            var visible = AttributedString(String(repeating: " ", count: range.lowerBound))
            visible += AttributedString(attributed[start..<end])
            return visible
        }
    }

    private func visibleWindow(in sourceText: String, viewport: CGRect) -> VisibleTextWindow {
        guard glyphPositions.isEmpty == false, sourceText == text,
              [viewport, fontGlyphBounds].allSatisfy({
                  $0.isNull == false && $0.isInfinite == false && $0.minX.isFinite && $0.maxX.isFinite
              }) else { return .original }
        let overhang = max(abs(fontGlyphBounds.minX), abs(fontGlyphBounds.maxX))
        var lower = 0
        var upper = glyphPositions.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if offset(at: middle + 1) + overhang < viewport.minX {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        let first = lower
        upper = glyphPositions.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if offset(at: middle) - overhang > viewport.maxX {
                upper = middle
            } else {
                lower = middle + 1
            }
        }
        guard first < lower, first > 0 || lower < glyphPositions.count else { return .original }
        let start = sourceText.index(sourceText.startIndex, offsetBy: first)
        let end = sourceText.index(start, offsetBy: lower - first)
        let visible = String(repeating: " ", count: first) + sourceText[start..<end]
        let measured = DiffTextBackgroundLayout(text: visible, font: font)
        guard measured.glyphPositions.count == lower,
              measured.glyphPositions.elementsEqual(glyphPositions.prefix(lower)),
              measured.offset(at: lower) == offset(at: lower) else { return .original }
        return .window(range: first..<lower, text: visible)
    }

    private func offset(at index: Int) -> CGFloat {
        if glyphPositions.indices.contains(index) {
            return glyphPositions[index].x
        }
        return CTLineGetOffsetForStringIndex(line, index, nil)
    }

    private static func glyphPositions(in line: CTLine, text: String, font: CTFont) -> [CGPoint] {
        guard CTFontGetSymbolicTraits(font).contains(.traitMonoSpace),
              DiffTextRunVisibility.supportsCulling(sourceText: text, highlighting: nil),
              let runs = CTLineGetGlyphRuns(line) as? [CTRun],
              runs.count == 1, let run = runs.first else { return [] }
        let characters = Array(text.utf16)
        let count = characters.count
        let stringRange = CTRunGetStringRange(run)
        guard count > 0, CTRunGetGlyphCount(run) == count,
              stringRange.location == 0, stringRange.length == count,
              CTRunGetStatus(run).isEmpty, CTRunGetTextMatrix(run).isIdentity else { return [] }

        var nominalGlyphs = Array(repeating: CGGlyph(0), count: count)
        guard CTFontGetGlyphsForCharacters(font, characters, &nominalGlyphs, count) else { return [] }
        var glyphs = Array(repeating: CGGlyph(0), count: count)
        var indices = Array(repeating: CFIndex(0), count: count)
        var positions = Array(repeating: CGPoint.zero, count: count)
        var advances = Array(repeating: CGSize.zero, count: count)
        var nominalAdvances = Array(repeating: CGSize.zero, count: count)
        let range = CFRange(location: 0, length: count)
        CTRunGetGlyphs(run, range, &glyphs)
        CTRunGetStringIndices(run, range, &indices)
        CTRunGetPositions(run, range, &positions)
        CTRunGetAdvances(run, range, &advances)
        _ = CTFontGetAdvancesForGlyphs(font, .horizontal, nominalGlyphs, &nominalAdvances, count)

        // Kerning can separate glyph origins from carets even with one glyph per character.
        guard glyphs == nominalGlyphs, advances == nominalAdvances,
              positions.first == CGPoint.zero else { return [] }
        let isValid = indices.withUnsafeBufferPointer { indexBuffer in
            positions.withUnsafeBufferPointer { positionBuffer in
                advances.withUnsafeBufferPointer { advanceBuffer in
                    let indexPointer = indexBuffer.baseAddress! // count > 0; indices has exactly count elements.
                    let positionPointer = positionBuffer.baseAddress! // count > 0; positions has exactly count elements.
                    let advancePointer = advanceBuffer.baseAddress! // count > 0; advances has exactly count elements.
                    var previousPosition = CGPoint.zero
                    var previousAdvance = CGSize.zero
                    var index = 0
                    while index < count {
                        let stringIndex = indexPointer[index]
                        let position = positionPointer[index]
                        let advance = advancePointer[index]
                        guard stringIndex == index,
                              position.x.isFinite, position.y.isFinite,
                              advance.width.isFinite, advance.width > 0,
                              advance.height.isFinite else { return false }
                        if index > 0 {
                            guard position.x == previousPosition.x + previousAdvance.width,
                                  position.y == previousPosition.y + previousAdvance.height else { return false }
                        }
                        previousPosition = position
                        previousAdvance = advance
                        index += 1
                    }
                    return true
                }
            }
        }
        guard isValid else { return [] }
        return positions
    }

    private enum VisibleTextWindow {
        case original
        case window(range: Range<Int>, text: String)
    }
}
