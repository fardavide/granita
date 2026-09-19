/// One channel of a frozen preview colour, as the stylesheet wrote it.
///
/// **A domain spelling rather than SwiftUI's `Color`**, for the same reason `HighlightAppearance` is
/// not `ColorScheme`: the table below is the pairing rule this feature is built on, and a rule that
/// can only be stated in a view layer cannot be tested without one. The view turns these into
/// `Color`; nothing here knows how.
public struct CodeColour: Hashable, Sendable {

    public let red: Double
    public let green: Double
    public let blue: Double

    /// **Total rather than failable, and taken as a literal rather than as a string.** A table of
    /// thirty colours behind a failable `init?(hex:)` is thirty force-unwraps or thirty optionals in
    /// a type that has no absent case; `0xAD3DA4` is the spelling a stylesheet uses and the compiler
    /// already refuses everything that is not one.
    public init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }
}

/// The five colours one half of a theme draws the preview sample in.
///
/// **They are not a summary of the stylesheet — for this sample they are the stylesheet.** Colour is
/// the only property `HighlightrSyntaxHighlighter` keeps, so the three lines of
/// `CodeThemeSample.source` have exactly these five answers in them and no sixth. That is what makes
/// a preview cost what a rectangle costs instead of a lexer pass.
public struct CodeThemePalette: Hashable, Sendable {

    public let comment: CodeColour
    public let keyword: CodeColour

    /// What an unclassified run is drawn in **on the preview card**.
    ///
    /// **Here as a colour and absent from the lexer's output, and the two are the same decision seen
    /// from both ends.** In a diff row the base colour is mapped to nothing so the row's own
    /// `.primary` draws it — that is the override `design-appearance.md` records. A preview card
    /// cannot do that: the dark half is a dark card inside a light sheet, so `.primary` there is the
    /// sheet's black on near-black. The half names its own plain colour because the half, not the
    /// environment, decides which appearance it is drawing.
    public let plain: CodeColour
    public let string: CodeColour
    public let type: CodeColour

    public init(
        comment: CodeColour,
        keyword: CodeColour,
        plain: CodeColour,
        string: CodeColour,
        type: CodeColour
    ) {
        self.comment = comment
        self.keyword = keyword
        self.plain = plain
        self.string = string
        self.type = type
    }
}

/// Where the lexer finds one half of a theme.
///
/// A distinct type keeps a Granita-owned stylesheet from accidentally being looked up in
/// Highlightr's private resource bundle, which was the limitation that originally kept custom
/// themes out of this table.
public enum CodeThemeStylesheet: Hashable, Sendable {

    case highlightrBundle(String)
    case clientBundle(String)
}

/// Which colours the code is lexed in, as a pair rather than as a stylesheet.
///
/// **A pair by name, from a table written here.** A dark-only theme is absent rather than paired with
/// an invented light half, because discarding the stylesheet background would otherwise put pale
/// tokens on Granita's white code card.
///
/// The original Xcode, Atom One and Stack Overflow pairs remain backed by Highlightr's resources.
/// Accessible, Granita, Catppuccin and GitHub are application-owned CSS with one declaration per
/// token role, so Highlightr's selector dictionary cannot choose a different colour between launches.
/// Every colour in those four pairs clears 4.5:1 on its white or `#1C1C1E` card; the measured minima
/// are recorded in `.ai/docs/design-appearance.md`.
public enum CodeTheme: String, Hashable, Sendable, CaseIterable {

    case xcode
    case atomOne
    case stackOverflow
    case accessible
    case granita
    case catppuccin
    case github

    /// The one a reader who has never opened this screen is already reading in.
    ///
    /// Shipped since 0.8.0 and chosen then because the code on the phone is code that was written in
    /// Xcode on the Mac beside it. It keeps that standing here: the list names it *Default* in one
    /// place, and the section marks it in none.
    public static let `default` = CodeTheme.xcode

    /// What the row says. **Not the stylesheet's name** — *Accessible* is named for what it is rather
    /// than for its files, and *Stack Overflow* has a space in it because it is a proper noun.
    public var displayName: String {
        switch self {
        case .xcode: "Xcode"
        case .atomOne: "Atom One"
        case .stackOverflow: "Stack Overflow"
        case .accessible: "Accessible"
        case .granita: "Granita"
        case .catppuccin: "Catppuccin"
        case .github: "GitHub"
        }
    }

    /// The highlight.js stylesheet this half is lexed with.
    ///
    /// The whole pairing table, including whether the resource belongs to Highlightr or Granita.
    public func stylesheet(for appearance: HighlightAppearance) -> CodeThemeStylesheet {
        switch (self, appearance) {
        case (.xcode, .light): .highlightrBundle("xcode")
        case (.xcode, .dark): .highlightrBundle("xcode-dark")
        case (.atomOne, .light): .highlightrBundle("atom-one-light")
        case (.atomOne, .dark): .highlightrBundle("atom-one-dark")
        case (.stackOverflow, .light): .highlightrBundle("stackoverflow-light")
        case (.stackOverflow, .dark): .highlightrBundle("stackoverflow-dark")
        case (.accessible, .light): .clientBundle("accessible-light")
        case (.accessible, .dark): .clientBundle("accessible-dark")
        case (.granita, .light): .clientBundle("granita-light")
        case (.granita, .dark): .clientBundle("granita-dark")
        case (.catppuccin, .light): .clientBundle("catppuccin-latte")
        case (.catppuccin, .dark): .clientBundle("catppuccin-mocha")
        case (.github, .light): .clientBundle("github-light")
        case (.github, .dark): .clientBundle("github-dark")
        }
    }

    /// The five colours the preview draws this half in, frozen.
    ///
    /// **Frozen rather than lexed, and pinned by a test rather than trusted.** A list of seven themes
    /// showing live-lexed samples is fourteen stylesheet swaps on the one actor the diff in front of
    /// the reader is also using; these cost what a rectangle costs. What stops them rotting is
    /// `CodeThemePaletteTests`, which lexes the sample with the real highlighter once per half and
    /// asserts these exact values — so the day Highlightr ships a changed stylesheet, a test says so
    /// instead of a reader noticing a preview that lies.
    ///
    /// **Every value here was measured rather than transcribed. Some bundled halves draw a role in the
    /// plain colour** because their stylesheet does not colour the class produced by the Swift grammar,
    /// so the run falls back to the stylesheet's base — which the base override then turns into the
    /// row's own `.primary`. A role that collapses is recorded here **as the plain colour**, because that is
    /// exactly what the diff draws: the preview and the file agree, which is the only property this
    /// table has to have. Which halves, and what it costs a reader, is in
    /// `.ai/docs/design-appearance.md`.
    public func palette(for appearance: HighlightAppearance) -> CodeThemePalette {
        switch (self, appearance) {
        // A half with five genuinely distinct colours and the palette every other
        // one is judged against. It is also the one the frames got furthest from: they drew this
        // comment as a slate `#5D6C79`, and `xcode.min.css` says green.
        case (.xcode, .light):
            CodeThemePalette(
                comment: CodeColour(0x007400),
                keyword: CodeColour(0xAA0D91),
                plain: CodeColour(0x000000),
                string: CodeColour(0xC41A16),
                type: CodeColour(0x5C2699)
            )
        // `type` is plain: `xcode-dark.min.css` colours the class `Bool` arrives in for its light
        // sibling and not for this one. **The shipped default has done this since 0.8.0** — this slice
        // reveals it rather than causing it, and changing it would be a different argument.
        case (.xcode, .dark):
            CodeThemePalette(
                comment: CodeColour(0x6C7986),
                keyword: CodeColour(0xFC5FA3),
                plain: CodeColour(0xFFFFFF),
                string: CodeColour(0xFC6A5D),
                type: CodeColour(0xFFFFFF)
            )
        // Both bundled halves have all four token roles intact.
        case (.atomOne, .light):
            CodeThemePalette(
                comment: CodeColour(0xA0A1A7),
                keyword: CodeColour(0xA626A4),
                plain: CodeColour(0x000000),
                string: CodeColour(0x50A14F),
                type: CodeColour(0x986801)
            )
        case (.atomOne, .dark):
            CodeThemePalette(
                comment: CodeColour(0x5C6370),
                keyword: CodeColour(0xC678DD),
                plain: CodeColour(0xFFFFFF),
                string: CodeColour(0x98C379),
                type: CodeColour(0xD19A66)
            )
        // The quietest of the three, and the only one with four distinct colours in both halves.
        case (.stackOverflow, .light):
            CodeThemePalette(
                comment: CodeColour(0x656E77),
                keyword: CodeColour(0x015692),
                plain: CodeColour(0x000000),
                string: CodeColour(0x54790D),
                type: CodeColour(0xB75501)
            )
        case (.stackOverflow, .dark):
            CodeThemePalette(
                comment: CodeColour(0x999999),
                keyword: CodeColour(0x88AECE),
                plain: CodeColour(0xFFFFFF),
                string: CodeColour(0xB5BD68),
                type: CodeColour(0xF08D49)
            )
        case (.accessible, .light):
            CodeThemePalette(
                comment: CodeColour(0x696969),
                keyword: CodeColour(0x7928A1),
                plain: CodeColour(0x000000),
                string: CodeColour(0x008000),
                type: CodeColour(0xAA5D00)
            )
        case (.accessible, .dark):
            CodeThemePalette(
                comment: CodeColour(0xD4D0AB),
                keyword: CodeColour(0xDCC6E0),
                plain: CodeColour(0xFFFFFF),
                string: CodeColour(0xABE338),
                type: CodeColour(0xF5AB35)
            )
        case (.granita, .light):
            CodeThemePalette(
                comment: CodeColour(0x52657A),
                keyword: CodeColour(0x6D28D9),
                plain: CodeColour(0x000000),
                string: CodeColour(0x00796B),
                type: CodeColour(0xC0265E)
            )
        case (.granita, .dark):
            CodeThemePalette(
                comment: CodeColour(0xA9B8CC),
                keyword: CodeColour(0xD6B4FC),
                plain: CodeColour(0xFFFFFF),
                string: CodeColour(0x7FE0C3),
                type: CodeColour(0xFF9DBB)
            )
        case (.catppuccin, .light):
            CodeThemePalette(
                comment: CodeColour(0x6C6F85),
                keyword: CodeColour(0x8839EF),
                plain: CodeColour(0x000000),
                string: CodeColour(0x1E66F5),
                type: CodeColour(0xD20F39)
            )
        case (.catppuccin, .dark):
            CodeThemePalette(
                comment: CodeColour(0xA6ADC8),
                keyword: CodeColour(0xCBA6F7),
                plain: CodeColour(0xFFFFFF),
                string: CodeColour(0xA6E3A1),
                type: CodeColour(0xF9E2AF)
            )
        case (.github, .light):
            CodeThemePalette(
                comment: CodeColour(0x6E7781),
                keyword: CodeColour(0xCF222E),
                plain: CodeColour(0x000000),
                string: CodeColour(0x0A3069),
                type: CodeColour(0x8250DF)
            )
        case (.github, .dark):
            CodeThemePalette(
                comment: CodeColour(0x8B949E),
                keyword: CodeColour(0xFF7B72),
                plain: CodeColour(0xFFFFFF),
                string: CodeColour(0xA5D6FF),
                type: CodeColour(0xD2A8FF)
            )
        }
    }
}

/// The three lines every preview in the app is drawn from.
///
/// **One sample for every theme and every half**, because the thing being compared is the colours
/// and a sample that varied would be comparing two things at once. Three lines rather than five:
/// the cell that holds two of these is 142pt wide, and what the reader is reading is the palette
/// rather than the code.
///
/// **Nothing in it is meant to be read**, which is why the view marks it decorative and gives the
/// theme's name as the accessibility label instead — a screen reader has no use for nine coloured
/// tokens.
public enum CodeThemeSample {

    /// Exactly the five classes `CodeThemePalette` carries, in three lines of Swift: a comment, two
    /// keywords, a string, a type, and plain runs between them.
    public static let source = """
        // changed
        let n = "review"
        func load() -> Bool
        """

    /// The language the sample is lexed as, which is the one this repository is written in.
    public static let language = "swift"
}
