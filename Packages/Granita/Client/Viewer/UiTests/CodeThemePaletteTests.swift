import CoreGraphics
import SwiftUI
import Testing

import ClientViewerDomain
@testable import ClientViewerUi

/// The one test standing between the theme shortlist and a table of colours that quietly
/// stops being true.
///
/// **Every preview in the app is drawn from `CodeTheme.palette(for:)` rather than from the lexer**,
/// because a list of seven themes showing live samples would be fourteen stylesheet swaps on the
/// one actor the diff in front of the reader is also using. That trade is only honest while the frozen values
/// are the stylesheets' own answers — so this lexes `CodeThemeSample.source` with the real
/// `HighlightrSyntaxHighlighter`, once per half, and compares what comes back with what is frozen.
///
/// **It fails the day Highlightr ships a changed stylesheet**, which is the failure mode a hand-kept
/// palette otherwise has and never announces: the previews would go on claiming colours the diff no
/// longer draws, and nothing would say so.
@Suite(.serialized)
struct CodeThemePaletteTests {

    @Test(arguments: CodeTheme.allCases, HighlightAppearance.allCases)
    func `given a theme half when the sample is lexed then its colours are the frozen ones`(
        theme: CodeTheme,
        appearance: HighlightAppearance
    ) async throws {
        let scenario = Scenario()

        let lexed = try #require(
            await scenario.sut.highlight(
                CodeThemeSample.source,
                as: CodeThemeSample.language,
                for: appearance,
                themed: theme
            ),
            "the sample must lex — a refusal here is a bundle that no longer carries Swift"
        )

        #expect(scenario.palette(of: lexed, plainBeing: theme.palette(for: appearance).plain)
            == theme.palette(for: appearance))
    }

    /// **The base override, asserted where it is observable.** A run the lexer did not classify has
    /// no foreground colour at all, so the row's own `.primary` draws it — which is what keeps a file
    /// the lexer refused and a file it accepted drawing their plain text identically, one scroll
    /// apart. Asserted per half rather than once, because it is the stylesheet's base that is being
    /// recognised and every stylesheet has a different one.
    @Test(arguments: CodeTheme.allCases, HighlightAppearance.allCases)
    func `given a theme half when the sample is lexed then unclassified text carries no colour`(
        theme: CodeTheme,
        appearance: HighlightAppearance
    ) async throws {
        let scenario = Scenario()

        let lexed = try #require(
            await scenario.sut.highlight(
                CodeThemeSample.source,
                as: CodeThemeSample.language,
                for: appearance,
                themed: theme
            )
        )

        #expect(scenario.colour(in: lexed[1], at: Scenario.plainOffset) == nil)
    }
}

// MARK: -

private struct Scenario {

    /// Where each of the four lexed roles sits in `CodeThemeSample.source`, as a line and an offset
    /// into it.
    ///
    /// Positions rather than a search, because what is being asserted is that *this* token came back
    /// *this* colour — a search for the first non-nil colour would pass on a stylesheet that coloured
    /// everything the same.
    static let commentOffset = (line: 0, character: 0)
    static let keywordOffset = (line: 1, character: 0)
    static let stringOffset = (line: 1, character: 9)
    static let typeOffset = (line: 2, character: 15)

    /// The space between `let` and `n`, which no grammar classifies.
    static let plainOffset = 3

    let sut = HighlightrSyntaxHighlighter()

    /// The four colours the lexer actually produced, read at the positions above.
    ///
    /// `plain` is filled from the half rather than from the lexer, because the lexer deliberately
    /// answers *nothing* there — the previous test is what asserts that, and putting a nil into a
    /// non-optional field here would have to invent a colour to do it.
    /// The palette the lexer actually produced, read at the positions above.
    ///
    /// **A role the lexer answered nothing for is recorded as the plain colour, and that is the
    /// assertion rather than a leniency in it.** Some bundled halves collapse a role into the base,
    /// and the base override then turns that into no colour at all, so the row draws it in `.primary`.
    /// The frozen table says
    /// *plain* for exactly those roles, so what this compares is the preview against the file: if a
    /// stylesheet update ever gives one of them its colour back, the table is wrong by one entry and
    /// this says so.
    func palette(of lines: [AttributedString], plainBeing plain: CodeColour) -> CodeThemePalette {
        CodeThemePalette(
            comment: colour(in: lines[Self.commentOffset.line], at: Self.commentOffset.character) ?? plain,
            keyword: colour(in: lines[Self.keywordOffset.line], at: Self.keywordOffset.character) ?? plain,
            plain: plain,
            string: colour(in: lines[Self.stringOffset.line], at: Self.stringOffset.character) ?? plain,
            type: colour(in: lines[Self.typeOffset.line], at: Self.typeOffset.character) ?? plain
        )
    }

    /// The colour of one character, or nothing when that character carries none.
    func colour(in line: AttributedString, at offset: Int) -> CodeColour? {
        let index = line.index(line.startIndex, offsetByCharacters: offset)
        guard let run = line.runs.first(where: { $0.range.contains(index) }),
              let colour = run.foregroundColor else {
            return nil
        }
        return Self.eightBit(of: colour)
    }

    // MARK: -

    /// A SwiftUI colour as the eight-bit triple a stylesheet wrote.
    ///
    /// Through `CGColor` in sRGB rather than through `Color.Resolved`'s components, because those are
    /// documented in one colour space and returned in another often enough that a comparison built on
    /// them fails by two units and looks like a changed stylesheet.
    private static func eightBit(of colour: Color) -> CodeColour? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = colour.resolve(in: EnvironmentValues()).cgColor
                .converted(to: space, intent: .defaultIntent, options: nil),
              let components = converted.components,
              components.count >= 3 else {
            return nil
        }
        let channel: (CGFloat) -> UInt32 = { UInt32((max(0, min(1, $0)) * 255).rounded()) }
        return CodeColour(channel(components[0]) << 16 | channel(components[1]) << 8 | channel(components[2]))
    }
}
