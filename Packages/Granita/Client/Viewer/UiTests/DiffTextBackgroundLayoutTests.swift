import CoreGraphics
import CoreText
import Foundation
import SwiftUI
import Testing

@testable import ClientViewerUi

@MainActor
@Suite(.serialized)
struct DiffTextBackgroundLayoutTests {

    @Test(arguments: [
        (0..<1, true, true),
        (0..<1, true, false),
        (9..<10, true, true),
        (9..<10, true, false),
        (9..<10, false, true),
        (9..<10, false, false),
        (16..<17, false, true),
        (16..<17, false, false)
    ])
    func `given shaped ASCII boundaries when selecting visible ranges then native caret edges determine inclusion`(
        changedRange: Range<Int>,
        viewportBeforeSpan: Bool,
        expectedVisible: Bool
    ) throws {
        // given
        let text = "AVATAR office ffi"
        let font = CTFontCreateWithName("Times-Roman" as CFString, 17, nil)
        let nativeText = NSMutableAttributedString(string: text)
        nativeText.addAttribute(
            NSAttributedString.Key(kCTFontAttributeName as String),
            value: font,
            range: NSRange(location: 0, length: nativeText.length)
        )
        let nativeLine = CTLineCreateWithAttributedString(nativeText)
        try #require(CTLineGetGlyphCount(nativeLine) < nativeText.length, "The fixture must exercise native ligature shaping")
        let nativeStart = CTLineGetOffsetForStringIndex(nativeLine, changedRange.lowerBound, nil)
        let nativeEnd = CTLineGetOffsetForStringIndex(nativeLine, changedRange.upperBound, nil)
        let fontBounds = CTFontGetBoundingBox(font)
        let overhang = max(abs(fontBounds.minX), abs(fontBounds.maxX))
        // Place the viewport immediately on either side of the native padded edge. This checks
        // complete-span inclusion at the line start, inside a ligature, and at the final boundary.
        let edgeInset: CGFloat = expectedVisible ? 1.0 / 1_024 : -1.0 / 1_024
        let viewport = CGRect(
            x: viewportBeforeSpan ? nativeStart - overhang + edgeInset - 1 : nativeEnd + overhang - edgeInset,
            y: 0, width: 1, height: 18
        )
        let layout = DiffTextBackgroundLayout(text: text, font: font)

        // when
        let visibleRanges = layout.visibleRanges(in: [changedRange], viewport: viewport)

        // then
        #expect(
            visibleRanges == (expectedVisible ? [changedRange] : []),
            "range=\(changedRange), nativeStart=\(nativeStart), nativeEnd=\(nativeEnd), overhang=\(overhang), viewport=\(viewport)"
        )
    }

    @Test(arguments: [true, false], [
        (0..<1, true, true),
        (0..<1, true, false),
        (1..<2, true, true),
        (1..<2, true, false),
        (1..<2, false, true),
        (1..<2, false, false),
        (13..<14, false, true),
        (13..<14, false, false)
    ])
    func `given native ASCII without ligatures when selecting visible ranges then kerned and trailing space boundaries are preserved`(
        isMonospaced: Bool,
        boundary: (changedRange: Range<Int>, viewportBeforeSpan: Bool, expectedVisible: Bool)
    ) throws {
        // given
        let text = "AVATAR WAVE   "
        let font = isMonospaced
            ? Font.system(size: 17, design: .monospaced)
                .resolve(in: EnvironmentValues().fontResolutionContext).ctFont
            : CTFontCreateWithName("Times-Roman" as CFString, 17, nil)
        let nativeText = NSMutableAttributedString(string: text)
        nativeText.addAttribute(
            NSAttributedString.Key(kCTFontAttributeName as String),
            value: font,
            range: NSRange(location: 0, length: nativeText.length)
        )
        let nativeLine = CTLineCreateWithAttributedString(nativeText)
        try #require(CTLineGetGlyphCount(nativeLine) == nativeText.length, "This fixture must not form a native ligature")
        if isMonospaced == false {
            let isolatedFirstCharacter = nativeText.attributedSubstring(from: NSRange(location: 0, length: 1))
            let isolatedLine = CTLineCreateWithAttributedString(isolatedFirstCharacter)
            let isolatedAdvance = CTLineGetOffsetForStringIndex(isolatedLine, 1, nil)
            let shapedAdvance = CTLineGetOffsetForStringIndex(nativeLine, 1, nil)
            try #require(abs(isolatedAdvance - shapedAdvance) > 1.0 / 1_024, "The proportional fixture must exercise native kerning")
        }
        let nativeStart = CTLineGetOffsetForStringIndex(nativeLine, boundary.changedRange.lowerBound, nil)
        let nativeEnd = CTLineGetOffsetForStringIndex(nativeLine, boundary.changedRange.upperBound, nil)
        let fontBounds = CTFontGetBoundingBox(font)
        let overhang = max(abs(fontBounds.minX), abs(fontBounds.maxX))
        let edgeInset: CGFloat = boundary.expectedVisible ? 1.0 / 1_024 : -1.0 / 1_024
        let viewport = CGRect(
            x: boundary.viewportBeforeSpan ? nativeStart - overhang + edgeInset - 1 : nativeEnd + overhang - edgeInset,
            y: 0, width: 1, height: 18
        )
        let layout = DiffTextBackgroundLayout(text: text, font: font)

        // when
        let visibleRanges = layout.visibleRanges(in: [boundary.changedRange], viewport: viewport)

        // then
        #expect(
            visibleRanges == (boundary.expectedVisible ? [boundary.changedRange] : []),
            "font=\(CTFontCopyPostScriptName(font)), range=\(boundary.changedRange), nativeStart=\(nativeStart), nativeEnd=\(nativeEnd), overhang=\(overhang), viewport=\(viewport)"
        )
    }

    @Test
    func `given a changed span far outside the native viewport when applying backgrounds then it is omitted`() throws {
        // given
        let text = "let values = [" + String(repeating: "value, ", count: 40) + "changed]"
        let changedRange = (text.count - 8)..<(text.count - 1)
        let font = Font.system(size: 12, design: .monospaced)
            .resolve(in: EnvironmentValues().fontResolutionContext).ctFont
        let viewport = CGRect(x: 0, y: 0, width: 100, height: 18)
        let nativeText = NSMutableAttributedString(string: text)
        nativeText.addAttribute(
            NSAttributedString.Key(kCTFontAttributeName as String),
            value: font,
            range: NSRange(location: 0, length: nativeText.length)
        )
        let nativeLine = CTLineCreateWithAttributedString(nativeText)
        let nativeSpanStart = CTLineGetOffsetForStringIndex(nativeLine, changedRange.lowerBound, nil)
        let nativeFontBounds = CTFontGetBoundingBox(font)
        try #require(nativeSpanStart > viewport.maxX + max(abs(nativeFontBounds.minX), abs(nativeFontBounds.maxX)))
        let layout = DiffTextBackgroundLayout(text: text, font: font)

        // when
        let shouldApplyBackground = layout.shouldApplyBackground(in: changedRange, viewport: viewport)

        // then
        #expect(!shouldApplyBackground)
    }

    @Test
    func `given a native font overhang reaches the viewport when applying backgrounds then the changed span is retained`() throws {
        // given
        let prefix = "let values = ["
        let text = prefix + "changed]"
        let changedRange = prefix.count..<(text.count - 1)
        let font = Font.system(size: 12, design: .monospaced)
            .resolve(in: EnvironmentValues().fontResolutionContext).ctFont
        let nativeText = NSMutableAttributedString(string: text)
        nativeText.addAttribute(
            NSAttributedString.Key(kCTFontAttributeName as String),
            value: font,
            range: NSRange(location: 0, length: nativeText.length)
        )
        let nativeLine = CTLineCreateWithAttributedString(nativeText)
        let nativeSpanStart = CTLineGetOffsetForStringIndex(nativeLine, changedRange.lowerBound, nil)
        let nativeFontBounds = CTFontGetBoundingBox(font)
        try #require(nativeFontBounds.minX < 0)
        let viewport = CGRect(
            x: nativeSpanStart + nativeFontBounds.minX / 2 - 100,
            y: 0, width: 100, height: 18
        )
        try #require(nativeSpanStart > viewport.maxX)
        try #require(nativeSpanStart + nativeFontBounds.minX < viewport.maxX)
        let layout = DiffTextBackgroundLayout(text: text, font: font)

        // when
        let shouldApplyBackground = layout.shouldApplyBackground(in: changedRange, viewport: viewport)

        // then
        #expect(shouldApplyBackground)
    }

    @Test
    func `given changed spans before inside and after the native viewport when selecting visible ranges then only the complete inside span remains`() throws {
        // given
        let text = String(repeating: "x", count: 80)
        let ranges = [1..<4, 36..<41, 74..<78]
        let font = Font.system(size: 12, design: .monospaced)
            .resolve(in: EnvironmentValues().fontResolutionContext).ctFont
        let nativeText = NSMutableAttributedString(string: text)
        nativeText.addAttribute(
            NSAttributedString.Key(kCTFontAttributeName as String),
            value: font,
            range: NSRange(location: 0, length: nativeText.length)
        )
        let nativeLine = CTLineCreateWithAttributedString(nativeText)
        let viewportStart = CTLineGetOffsetForStringIndex(nativeLine, 30, nil)
        let viewportEnd = CTLineGetOffsetForStringIndex(nativeLine, 50, nil)
        let viewport = CGRect(x: viewportStart, y: 0, width: viewportEnd - viewportStart, height: 18)
        let nativeFontBounds = CTFontGetBoundingBox(font)
        let overhang = max(abs(nativeFontBounds.minX), abs(nativeFontBounds.maxX))
        try #require(CTLineGetOffsetForStringIndex(nativeLine, 4, nil) + overhang < viewport.minX)
        try #require(CTLineGetOffsetForStringIndex(nativeLine, 36, nil) > viewport.minX)
        try #require(CTLineGetOffsetForStringIndex(nativeLine, 41, nil) < viewport.maxX)
        try #require(CTLineGetOffsetForStringIndex(nativeLine, 74, nil) - overhang > viewport.maxX)
        let layout = DiffTextBackgroundLayout(text: text, font: font)

        // when
        let visibleRanges = layout.visibleRanges(in: ranges, viewport: viewport)

        // then
        #expect(visibleRanges == [36..<41])
    }

    @Test
    func `given an unknown native viewport when selecting visible ranges then every original range is retained`() {
        // given
        let text = String(repeating: "x", count: 80)
        let ranges = [1..<4, 36..<41, 74..<78]
        let font = Font.system(size: 12, design: .monospaced)
            .resolve(in: EnvironmentValues().fontResolutionContext).ctFont
        let layout = DiffTextBackgroundLayout(text: text, font: font)

        // when
        let visibleRanges = layout.visibleRanges(in: ranges, viewport: .null)

        // then
        #expect(visibleRanges == [1..<4, 36..<41, 74..<78])
    }

    @Test
    func `given an empty native line when selecting visible ranges then no backgrounds are selected`() {
        // given
        let font = CTFontCreateWithName("Times-Roman" as CFString, 17, nil)
        let layout = DiffTextBackgroundLayout(text: "", font: font)

        // when
        let visibleRanges = layout.visibleRanges(in: [], viewport: CGRect(x: 0, y: 0, width: 100, height: 18))

        // then
        #expect(visibleRanges.isEmpty)
    }
}
