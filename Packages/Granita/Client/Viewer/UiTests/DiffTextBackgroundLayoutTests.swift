import CoreGraphics
import CoreText
import Foundation
import SwiftUI
import Testing

@testable import ClientViewerUi

@MainActor
@Suite(.serialized)
struct DiffTextBackgroundLayoutTests {

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
}
