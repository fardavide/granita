import SwiftUI

import ClientViewerDomain

private extension Color {

    /// One channel triple as SwiftUI sees it.
    ///
    /// **Built from the frozen palette rather than resolved from the environment**, which is the whole
    /// point of the two cards: the dark half has to draw its dark colours inside a light sheet, so
    /// nothing here may consult `colorScheme`.
    init(_ colour: CodeColour) {
        self.init(red: colour.red, green: colour.green, blue: colour.blue)
    }
}

/// One half of a theme, drawn rather than lexed.
///
/// **Three lines and five colours, and neither is fetched, computed at open or capable of being
/// stale.** A list of seven themes showing live samples would be fourteen stylesheet swaps on the
/// one actor the diff behind this sheet is also using; this costs what a rectangle costs, and
/// `CodeThemePaletteTests` is what keeps the rectangle honest.
///
/// **It carries its own card colour and its own hairline in both appearances.** In light the light
/// half is white on a white card and in dark the dark half is `#1C1C1E` on a `#1C1C1E` card — so
/// whichever appearance the reader is in, one of the two would have no edge, and the one without an
/// edge is always the one they are currently living in.
///
/// **Decorative, and deliberately.** A screen reader has no use for nine coloured tokens, so nothing
/// in here is focusable and the row above names the theme instead.
public struct CodeThemeSampleView: View {

    private let palette: CodeThemePalette
    private let appearance: HighlightAppearance

    public init(palette: CodeThemePalette, appearance: HighlightAppearance) {
        self.palette = palette
        self.appearance = appearance
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("// changed")
                .foregroundStyle(Color(palette.comment))
            // Composed rather than three `Text`s in an `HStack`, so the runs sit on one baseline at one
            // spacing the way a line of code does — an `HStack` would put its own gaps between the
            // keyword and the name.
            Text("let").foregroundStyle(Color(palette.keyword))
                + Text(" n = ").foregroundStyle(Color(palette.plain))
                + Text("\"review\"").foregroundStyle(Color(palette.string))
            Text("func").foregroundStyle(Color(palette.keyword))
                + Text(" load() -> ").foregroundStyle(Color(palette.plain))
                + Text("Bool").foregroundStyle(Color(palette.type))
        }
        .font(.system(size: 10, design: .monospaced))
        // **One line, never wrapped and never truncated with a marker.** The sample is a paint chip:
        // an ellipsis in it would read as content the reader is missing rather than as a card too
        // narrow, and `lineLimit(1)` with `.clipped()` is what the frames draw at 142pt.
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(card, in: .rect(cornerRadius: 6))
        // **The hairline follows the sheet rather than the card, which is why it is the semantic style
        // and not a literal like the card beneath it.** In light both cards are outlined in the light
        // separator and in dark both in the dark one — otherwise the half the reader is living in is
        // the one that loses its edge, since a white card on a white sheet and a `#1C1C1E` card on a
        // `#1C1C1E` sheet are each invisible in their own appearance.
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator, lineWidth: 0.5))
        .clipped()
        .accessibilityHidden(true)
    }

    // MARK: -

    /// The card this half is drawn on, which is the appearance's own grouped-cell colour stated
    /// literally.
    ///
    /// **Literal rather than semantic, and that is the one place this view cannot use the system's
    /// own answer.** `secondarySystemGroupedBackground` resolves against the environment, and half of
    /// what this view exists to draw is the appearance the environment is *not* in.
    private var card: Color {
        switch appearance {
        case .light: Color(red: 1, green: 1, blue: 1)
        case .dark: Color(red: 0.110, green: 0.110, blue: 0.118)
        }
    }
}

/// Both halves of a theme, side by side, light on the left.
///
/// **This is the answer to the question the whole slice was asked for**: the half the phone is not
/// currently drawing is already on screen, at full strength, next to the half it is. Not behind a
/// toggle, not behind a change of appearance, not behind a tap.
public struct CodeThemePairView: View {

    private let theme: CodeTheme

    /// Which half the phone is currently drawing, or nothing where saying so would be noise.
    ///
    /// **Absent in the chooser and present in the section**, which is the design's own split: five
    /// rows each captioned *Light* and *Dark* is the same two words ten times, and the cards say it
    /// by being white and near-black. In the section there is one pair and a live question about which
    /// half the reader is in, so the marker earns its line there.
    private let inUse: HighlightAppearance?

    public init(theme: CodeTheme, inUse: HighlightAppearance? = nil) {
        self.theme = theme
        self.inUse = inUse
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(HighlightAppearance.allCases, id: \.self) { appearance in
                VStack(alignment: .leading, spacing: 4) {
                    if inUse != nil {
                        caption(for: appearance)
                    }
                    CodeThemeSampleView(palette: theme.palette(for: appearance), appearance: appearance)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: -

    /// *Light* or *Dark*, and on the half being drawn, *in use* with a dot.
    ///
    /// **Without the marker the reader sees two swatches and cannot tell which one is their screen**,
    /// which turns the honest answer into a puzzle. It is the label's own colour rather than a new
    /// one: this section has no accent to spend and no state to report.
    @ViewBuilder
    private func caption(for appearance: HighlightAppearance) -> some View {
        let isInUse = appearance == inUse
        HStack(spacing: 4) {
            if isInUse {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 5, height: 5)
            }
            Text(isInUse ? "\(appearance.displayName) · in use" : appearance.displayName)
        }
        .font(.caption2)
        .fontWeight(isInUse ? .semibold : .regular)
        .foregroundStyle(isInUse ? Color.primary : Color.secondary)
    }
}

// MARK: -

private extension HighlightAppearance {

    /// What the caption under a sample says.
    var displayName: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
