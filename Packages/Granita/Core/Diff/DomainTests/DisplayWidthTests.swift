import Foundation
import Testing

@testable import CoreDiffDomain

/// The viewer reserves scroll space from these numbers before it has laid a line out, so a wrong
/// count is a row-count error in a scroll that must never reflow above the viewport.
@Suite("Display width")
struct DisplayWidthTests {

    // MARK: - Columns

    @Test
    func `given plain ascii when measured then every character counts one`() {
        // given - when
        let width = DisplayWidth(of: "no tabs, plain ascii")

        // then
        #expect(width.columns == 20)
    }

    @Test
    func `given a tab at the start of a line when measured then it fills a whole group of four`() {
        // given - when
        let width = DisplayWidth(of: "\tone tab then text")

        // then — 4 for the tab, 17 for the text.
        #expect(width.columns == 21)
    }

    @Test
    func `given a tab after two characters when measured then it stops at the next multiple of four`() {
        // given - when
        let width = DisplayWidth(of: "ab\tc")

        // then — the tab advances from column 2 to column 4, so it is worth two, not four.
        #expect(width.columns == 5)
    }

    @Test
    func `given a tab on a multiple of four when measured then it advances a full four`() {
        // given - when
        let width = DisplayWidth(of: "abcd\t")

        // then
        #expect(width.columns == 8)
    }

    @Test
    func `given east asian wide characters when measured then each counts two`() {
        // given - when
        let width = DisplayWidth(of: "wide 日本語 characters")

        // then — 5 leading, 6 for the three wide characters, 11 trailing.
        #expect(width.columns == 22)
    }

    @Test
    func `given a combining mark when measured then it counts nothing`() {
        // given — a decomposed é: the acute is a separate scalar occupying no column of its own.
        let text = "combining e\u{0301} mark"

        // when
        let width = DisplayWidth(of: text)

        // then
        #expect(width.columns == 16)
    }

    @Test
    func `given a carriage return when measured then it counts nothing`() {
        // given — CRLF is preserved verbatim in the line text, so the CR is content that renders
        // nothing. Counting it would over-measure every line of every CRLF file.
        let width = DisplayWidth(of: "first\r")

        // then
        #expect(width.columns == 5)
    }

    @Test
    func `given an east asian ambiguous character when measured then it counts one`() {
        // given - when — è and — are Ambiguous, and narrow in the monospaced fonts the viewer uses.
        let width = DisplayWidth(of: "caffè — 3")

        // then
        #expect(width.columns == 9)
    }

    @Test
    func `given an emoji when measured then it counts two as a best effort`() {
        // given - when
        let width = DisplayWidth(of: "ice 🧊")

        // then
        #expect(width.columns == 6)
    }

    // MARK: - Needs measurement

    @Test
    func `given ordinary european prose when measured then the client is not asked to measure it`() {
        // given - when
        let width = DisplayWidth(of: "caffè — the naïve résumé of a Grünanlage")

        // then — flagging this would push most European text onto the slow measured path.
        #expect(width.needsMeasurement == false)
    }

    @Test
    func `given wide characters when measured then the client is not asked to measure them`() {
        // given - when
        let width = DisplayWidth(of: "日本語")

        // then
        #expect(width.needsMeasurement == false)
    }

    @Test
    func `given an emoji when measured then the client is asked to measure the line`() {
        // given - when
        let width = DisplayWidth(of: "unicode path, edited — caffè 日本語 🧊")

        // then
        #expect(width.needsMeasurement)
    }

    @Test
    func `given a joined emoji sequence when measured then the client is asked to measure the line`() {
        // given — one rendered glyph built from five scalars, which no arithmetic here can predict.
        let width = DisplayWidth(of: "family 👨‍👩‍👧")

        // then
        #expect(width.needsMeasurement)
    }

    @Test
    func `given a variation selector when measured then the client is asked to measure the line`() {
        // given — a text-presentation glyph turned into an emoji one by the selector alone.
        let width = DisplayWidth(of: "heart \u{2764}\u{FE0F}")

        // then
        #expect(width.needsMeasurement)
    }

    @Test
    func `given a script that reshapes its characters when measured then the client is asked to measure the line`() {
        // given — Arabic joins and Devanagari reorders, so per-scalar arithmetic cannot predict the
        // rendered advance.
        let arabic = DisplayWidth(of: "مرحبا")
        let devanagari = DisplayWidth(of: "नमस्ते")

        // then
        #expect(arabic.needsMeasurement)
        #expect(devanagari.needsMeasurement)
    }

    @Test
    func `given an empty line when measured then it is zero columns and needs nothing`() {
        // given - when
        let width = DisplayWidth(of: "")

        // then
        #expect(width.columns == 0)
        #expect(width.needsMeasurement == false)
    }
}
