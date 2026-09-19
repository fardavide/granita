import Testing

import ClientViewerDomain

/// The pairing table, asserted as a table rather than as a rendering.
///
/// **`CodeThemePaletteTests` holds the colours against the real lexer; this holds the shape.** A pair
/// that named one stylesheet twice, a theme with no word for its row, or a default that is not in the
/// list are all defects a palette assertion would sail past — and all three are one line of data
/// apart from being correct.
@Suite("Code themes")
struct CodeThemeTests {

    @Test(arguments: CodeTheme.allCases)
    func `given a theme when it is named then the row has a word for it`(theme: CodeTheme) {
        // given - when - then — the list and the section both draw this, and the chooser is built from
        // `allCases`, so a fourth case added without a name would draw a blank row rather than fail to
        // compile.
        #expect(theme.displayName.isEmpty == false)
    }

    @Test(arguments: CodeTheme.allCases)
    func `given a theme when its two halves are asked for then they are different stylesheets`(
        theme: CodeTheme
    ) {
        // given - when - then — **the one invariant the table cannot be allowed to break.** Both halves
        // naming one stylesheet is a pair that renders light colours on a dark card, which is the exact
        // failure `lines(of:)` discarding the background makes possible — and it would look like a
        // typo in a data table nobody reads twice.
        #expect(theme.stylesheet(for: .light) != theme.stylesheet(for: .dark))
    }

    @Test
    func `given the shipped themes when their stylesheets are listed then none is shared`() {
        // given - when - then — two themes resolving to one stylesheet would be two rows drawing an
        // identical pair, so the reader would be offered a choice that changes nothing.
        let all = CodeTheme.allCases.flatMap { theme in
            HighlightAppearance.allCases.map(theme.stylesheet(for:))
        }
        #expect(Set(all).count == all.count)
    }

    @Test
    func `given the default theme when the list is drawn then it is in it`() {
        // given - when - then — the chooser marks one row *Default* and the section marks none, so a
        // default outside `allCases` would be a value no screen can show and no reader can choose back.
        #expect(CodeTheme.allCases.contains(CodeTheme.default))
    }

    @Test(arguments: CodeTheme.allCases)
    func `given a theme when its halves are asked for then their plain colours are label's`(
        theme: CodeTheme
    ) {
        // given - when - then — **the preview's card has to agree with the diff's row**, and the row
        // draws unclassified text in `.primary`: black in light, white in dark. A half whose plain
        // colour drifted off those two would draw a sample that does not match the file it describes,
        // which is the one thing a frozen palette is for.
        #expect(theme.palette(for: .light).plain == CodeColour(0x000000))
        #expect(theme.palette(for: .dark).plain == CodeColour(0xFFFFFF))
    }

    @Test
    func `given the sample when it is read then it carries all five classes`() {
        // given - when - then — three lines holding a comment, two keywords, a string and a type, with
        // plain runs between them. The palette has five fields because the sample has five answers, and
        // a sample edited down to four would leave a field nothing measures.
        #expect(CodeThemeSample.source.contains("// changed"))
        #expect(CodeThemeSample.source.contains("let"))
        #expect(CodeThemeSample.source.contains("\"review\""))
        #expect(CodeThemeSample.source.contains("Bool"))
        #expect(CodeThemeSample.language == "swift")
    }
}
