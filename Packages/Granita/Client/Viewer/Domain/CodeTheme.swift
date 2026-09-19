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

/// Which colours the code is lexed in, as a pair rather than as a stylesheet.
///
/// **A pair by name, from a table written here, and the measurement is what settles that rather than
/// taste.** Highlightr bundles 271 stylesheets and only 40 of them carry a matched `-light`/`-dark`
/// pair — Granita's own default is not one of them, being `xcode` and `xcode-dark`. So a pairing
/// table has to exist in *either* design: letting a reader choose the two halves independently does
/// not avoid this table, it only stops using it, and what it buys instead is 271 × 271 combinations
/// of which the great majority are broken. `lines(of:)` discards the stylesheet's background, so a
/// dark stylesheet asked for in light appearance paints pale grey on white.
///
/// **Three cases, and two criteria decide them.** Both halves exist in the bundle as a pair, **and the
/// stylesheet renders the same colours on every launch.** A theme that fails either is **absent** rather
/// than a greyed row — which is the second state the never-ship-a-dead-control rule permits, and the
/// right one when the alternative is a row that explains a contrast ratio.
///
/// **Contrast and chroma are measured and reported, not gated, and saying otherwise was wrong.** The
/// design return published four criteria including *every colour clears 4.5:1 on our card*; measuring
/// all 271 stylesheets on 19 September 2026 showed that no shipped pair satisfies it — `xcode-dark`
/// draws comments at 3.8:1 and `atom-one` at 2.6:1 — and that Xcode is the second most saturated of the
/// eight stable pairs, so it is no chroma ceiling either. The figures per pair are in
/// `.ai/docs/design-appearance.md`; what they are *not* is a thing this type enforces.
///
/// **The fifth criterion is this repository's rather than the design's, and it is what took the count
/// from the five that were drawn to the three that ship.** Highlightr's stylesheet stripper keys rules
/// by selector in a `Dictionary` and understands neither `@media` blocks nor descendant selectors: it
/// reduces `.hljs-meta .hljs-keyword` onto the bare `.hljs-keyword`. So when a stylesheet declares one
/// of these roles more than once with different values, which declaration wins is decided by a
/// dictionary iteration order Swift randomises per process — the colours change when the app is
/// relaunched, and a frozen palette for it cannot exist. Two of the five drawn pairs fail it, and both
/// failures were observed rather than reasoned: lexing the sample in separate processes returned
/// different palettes.
///
/// - **Accessible**, on `a11y-light`/`a11y-dark`, declares `.hljs-keyword` twice — once for colour and
///   once for `font-weight` — and redeclares comment, string and type inside
///   `@media (-ms-high-contrast:active)`. Four of its four roles move. It is the loss that costs most,
///   because it was the only pair drawn against a contrast target.
/// - **GitHub**, on `github`/`github-dark`, has three declarations reducing to `.hljs-keyword`
///   (`#a71d5d`, `#333`, and one with no colour at all) and two reducing to `.hljs-string`
///   (`#183691`, `#333`).
///
/// Measured 19 September 2026. Recorded in `.ai/docs/decisions.md` and `.ai/docs/design-appearance.md`.
///
/// **Solarized is the interesting exclusion, and not for the reason the return gave.** It was excluded
/// for a comment grey said to be 2.4:1 on white; on our card it measures 3.2:1, better than the Atom One
/// that ships. It fails the second criterion instead: `solarized-light` gives `.hljs-keyword` both
/// `#6c71c4` and `#d33682`, because Highlightr splits `.hljs-meta .hljs-keyword` onto the bare class.
/// The same defect as `github`, hidden behind a figure that does not reproduce.
///
/// **Dracula, Nord and Monokai are refused twice over.** They are dark with no light sibling — and
/// measuring them for the other question, whether one stylesheet could serve both halves since we
/// discard its background, they turn out to declare `.hljs-keyword` two ways as well. A dark-tuned
/// palette is also pale: the stable dark-only stylesheets measure 1.0–2.9:1 on a white card. Every call
/// and the alternative it beat is in `.ai/docs/design-appearance.md`;
/// [#103](https://github.com/fardavide/granita/issues/103) is the route that does not go through this
/// bundle.
public enum CodeTheme: String, Hashable, Sendable, CaseIterable {

    case xcode
    case atomOne
    case stackOverflow

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
        }
    }

    /// The highlight.js stylesheet this half is lexed with.
    ///
    /// The whole of the pairing table, and the reason it cannot be a suffix rule: `xcode` pairs with
    /// `xcode-dark`, `github` with `github-dark`, and only two of the five follow the `-light`
    /// convention at all.
    public func stylesheet(for appearance: HighlightAppearance) -> String {
        switch (self, appearance) {
        case (.xcode, .light): "xcode"
        case (.xcode, .dark): "xcode-dark"
        case (.atomOne, .light): "atom-one-light"
        case (.atomOne, .dark): "atom-one-dark"
        case (.stackOverflow, .light): "stackoverflow-light"
        case (.stackOverflow, .dark): "stackoverflow-dark"
        }
    }

    /// The five colours the preview draws this half in, frozen.
    ///
    /// **Frozen rather than lexed, and pinned by a test rather than trusted.** A list of five themes
    /// showing live-lexed samples is ten stylesheet swaps on the one actor the diff in front of the
    /// reader is also using; these cost what a rectangle costs. What stops them rotting is
    /// `CodeThemePaletteTests`, which lexes the sample with the real highlighter once per half and
    /// asserts these exact values — so the day Highlightr ships a changed stylesheet, a test says so
    /// instead of a reader noticing a preview that lies.
    ///
    /// **Every value here was measured rather than transcribed, and five of the ten halves draw a role
    /// in the plain colour** — which is the one place this table departs from the frames that asked for
    /// it. The frames assumed five distinct colours per half; the bundle does not always provide them,
    /// because Highlightr's stylesheet parser keys its rules by selector and a later rule for the same
    /// selector replaces the earlier one. `a11y-light` says `.hljs-keyword{color:#7928a1}` and then
    /// `.hljs-keyword{font-weight:700}`, so the colour is gone by the time a keyword is drawn and the
    /// run falls back to the stylesheet's base — which the base override then turns into the row's own
    /// `.primary`. So a role that collapses is recorded here **as the plain colour**, because that is
    /// exactly what the diff draws: the preview and the file agree, which is the only property this
    /// table has to have. Which halves, and what it costs a reader, is in
    /// `.ai/docs/design-appearance.md`.
    public func palette(for appearance: HighlightAppearance) -> CodeThemePalette {
        switch (self, appearance) {
        // The only half of the ten with five genuinely distinct colours and the palette every other
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
        // Both halves intact, and the only pair besides Stack Overflow that manages it.
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
