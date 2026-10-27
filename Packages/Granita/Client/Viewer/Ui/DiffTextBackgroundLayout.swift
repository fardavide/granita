import CoreGraphics
import CoreText
import Foundation

struct DiffTextBackgroundLayout {
    private let line: CTLine
    private let fontGlyphBounds: CGRect
    private let glyphPositions: [CGFloat]

    init(text: String, font: CTFont) {
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

    private func offset(at index: Int) -> CGFloat {
        if glyphPositions.indices.contains(index) {
            return glyphPositions[index]
        }
        return CTLineGetOffsetForStringIndex(line, index, nil)
    }

    private static func glyphPositions(in line: CTLine, text: String, font: CTFont) -> [CGFloat] {
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
        guard positions.first == CGPoint.zero else { return [] }
        for index in positions.indices {
            guard indices[index] == index, glyphs[index] == nominalGlyphs[index],
                  positions[index].x.isFinite, positions[index].y.isFinite,
                  advances[index].width.isFinite, advances[index].height.isFinite,
                  advances[index] == nominalAdvances[index] else { return [] }
            if index > 0 {
                let previous = positions[index - 1]
                let advance = advances[index - 1]
                guard positions[index].x == previous.x + advance.width,
                      positions[index].y == previous.y + advance.height else { return [] }
            }
        }
        return positions.map(\.x)
    }
}
