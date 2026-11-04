import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import ClientViewerUi

@Suite(.serialized)
struct DiffTextRunVisibilityTests {

    @Test
    func `given a run far outside the viewport when deciding visibility then it is not drawn`() {
        // given
        let runBounds = CGRect(x: 1_000, y: 0, width: 10, height: 18)
        let viewport = CGRect(x: 0, y: 0, width: 100, height: 18)
        let fontGlyphBounds = CGRect(x: -3, y: -4, width: 18, height: 22)

        // when
        let shouldDraw = DiffTextRunVisibility.shouldDraw(
            runBounds: runBounds,
            viewport: viewport,
            fontGlyphBounds: fontGlyphBounds
        )

        // then
        #expect(!shouldDraw)
    }

    @Test
    func `given a glyph overhang reaches the viewport when deciding visibility then the run is drawn`() {
        // given
        let runBounds = CGRect(x: 110, y: 0, width: 10, height: 18)
        let viewport = CGRect(x: 0, y: 0, width: 100, height: 18)
        let fontGlyphBounds = CGRect(x: -3, y: -4, width: 18, height: 22)

        // when
        let shouldDraw = DiffTextRunVisibility.shouldDraw(
            runBounds: runBounds,
            viewport: viewport,
            fontGlyphBounds: fontGlyphBounds
        )

        // then
        #expect(shouldDraw)
    }

    @Test(arguments: [
        (
            CGRect.null,
            CGRect(x: 0, y: 0, width: 100, height: 18),
            CGRect(x: -3, y: -4, width: 18, height: 22)
        ),
        (
            CGRect(x: 1_000, y: 0, width: 10, height: 18),
            CGRect.infinite,
            CGRect(x: -3, y: -4, width: 18, height: 22)
        ),
        (
            CGRect(x: 1_000, y: 0, width: 10, height: 18),
            CGRect(x: 0, y: 0, width: 100, height: 18),
            CGRect(x: CGFloat.nan, y: -4, width: 18, height: 22)
        )
    ])
    func `given unknown native geometry when deciding visibility then the run remains drawn`(
        runBounds: CGRect,
        viewport: CGRect,
        fontGlyphBounds: CGRect
    ) {
        // when
        let shouldDraw = DiffTextRunVisibility.shouldDraw(
            runBounds: runBounds,
            viewport: viewport,
            fontGlyphBounds: fontGlyphBounds
        )

        // then
        #expect(shouldDraw)
    }

    @Test(arguments: ["", "let value = 42", " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"])
    func `given printable ASCII without highlighting when checking culling support then it is supported`(
        sourceText: String
    ) {
        // when
        let supportsCulling = DiffTextRunVisibility.supportsCulling(
            sourceText: sourceText,
            highlighting: nil
        )

        // then
        #expect(supportsCulling)
    }

    @Test(arguments: ["e\u{0301}", "left\tright", "first\nsecond", "first\r\nsecond"])
    func `given Unicode or control text when checking culling support then original rendering is required`(
        sourceText: String
    ) {
        // when
        let supportsCulling = DiffTextRunVisibility.supportsCulling(
            sourceText: sourceText,
            highlighting: nil
        )

        // then
        #expect(!supportsCulling)
    }

    @Test(arguments: ["e\u{0301}x", "x\t"])
    func `given ASCII source with Unicode or control highlighting when checking culling support then original rendering is required`(
        highlightedText: String
    ) {
        // given
        let sourceText = "ab"
        let highlighting = AttributedString(highlightedText)

        // when
        let supportsCulling = DiffTextRunVisibility.supportsCulling(
            sourceText: sourceText,
            highlighting: highlighting
        )

        // then
        #expect(!supportsCulling)
    }

    @Test
    func `given highlighting with a custom font when checking culling support then original rendering is required`() {
        // given
        let sourceText = "let value = 42"
        var highlighting = AttributedString(sourceText)
        highlighting.font = .system(size: 48, weight: .heavy, design: .serif)

        // when
        let supportsCulling = DiffTextRunVisibility.supportsCulling(
            sourceText: sourceText,
            highlighting: highlighting
        )

        // then
        #expect(!supportsCulling)
    }

    @Test
    func `given ASCII highlighting with only foreground colors when checking culling support then it is supported`() {
        // given
        let sourceText = "let value = 42"
        var highlighting = AttributedString("let")
        highlighting.foregroundColor = .red
        highlighting.append(AttributedString(" value = "))
        var literal = AttributedString("42")
        literal.foregroundColor = .blue
        highlighting.append(literal)

        // when
        let supportsCulling = DiffTextRunVisibility.supportsCulling(
            sourceText: sourceText,
            highlighting: highlighting
        )

        // then
        #expect(supportsCulling)
    }
}
