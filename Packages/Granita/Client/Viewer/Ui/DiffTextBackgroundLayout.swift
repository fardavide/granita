import CoreGraphics
import CoreText
import Foundation

struct DiffTextBackgroundLayout {
    private let line: CTLine
    private let fontGlyphBounds: CGRect

    init(text: String, font: CTFont) {
        line = CTLineCreateWithAttributedString(NSAttributedString(
            string: text,
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
        ) as CFAttributedString)
        fontGlyphBounds = CTFontGetBoundingBox(font)
    }

    func shouldApplyBackground(in range: Range<Int>, viewport: CGRect) -> Bool {
        let start = CTLineGetOffsetForStringIndex(line, range.lowerBound, nil)
        let end = CTLineGetOffsetForStringIndex(line, range.upperBound, nil)
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
            let end = CTLineGetOffsetForStringIndex(line, ranges[middle].upperBound, nil)
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
            let start = CTLineGetOffsetForStringIndex(line, ranges[middle].lowerBound, nil)
            guard start.isFinite else { return ranges }
            if start - overhang > viewport.maxX {
                upper = middle
            } else {
                lower = middle + 1
            }
        }
        return ranges[first..<lower].filter { shouldApplyBackground(in: $0, viewport: viewport) }
    }
}
