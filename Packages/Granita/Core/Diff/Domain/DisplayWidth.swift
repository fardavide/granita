import Foundation

/// How many columns a line occupies in the viewer's monospaced grid, and whether that number can be
/// trusted.
///
/// Measured here, once, rather than on the client: the viewer reserves scroll space per line before
/// laying anything out, and the two sides re-deriving the same Unicode judgement independently is a
/// disagreement waiting to become a row-count error in a scroll that must never reflow.
struct DisplayWidth: Hashable {

    let columns: Int

    /// Whether `columns` is a best effort the client should replace by measuring the line for real.
    let needsMeasurement: Bool

    init(of text: String) {
        var columns = 0
        var needsMeasurement = false
        for scalar in text.unicodeScalars {
            if scalar == "\t" {
                columns += MonospacedGrid.tabStop - columns % MonospacedGrid.tabStop
                continue
            }
            columns += scalar.displayColumns
            needsMeasurement = needsMeasurement || scalar.rendersUnpredictably
        }
        self.columns = columns
        self.needsMeasurement = needsMeasurement
    }
}

private extension Unicode.Scalar {

    var displayColumns: Int {
        if isAscii {
            // Control characters render nothing; a CR reaches here on every line of a CRLF file,
            // because CRLF is preserved verbatim in the line text.
            return properties.generalCategory == .control ? 0 : 1
        }
        switch properties.generalCategory {
        case .control, .format, .nonspacingMark, .enclosingMark:
            return 0
        default:
            break
        }
        // Everything with Emoji_Presentation is East Asian Wide, so two is the best effort even
        // though the line is going to be measured for real anyway.
        if properties.isEmojiPresentation {
            return 2
        }
        return wideRanges.contains { $0.contains(value) } ? 2 : 1
    }

    /// Whether this scalar puts the whole line outside what per-scalar arithmetic can predict.
    ///
    /// Deliberately not flagged: East Asian *Ambiguous* characters. `è` and `—` are Ambiguous and
    /// narrow in the monospaced fonts the viewer uses, and flagging them would push ordinary
    /// European prose onto the slow measured path.
    var rendersUnpredictably: Bool {
        if isAscii {
            return false
        }
        // A joiner or a variation selector means the glyph on screen is not the scalars in the
        // string, so nothing counted per scalar can be right.
        if self == zeroWidthJoiner || variationSelectorRanges.contains(where: { $0.contains(value) }) {
            return true
        }
        if properties.isEmojiPresentation {
            return true
        }
        return reshapingScriptRanges.contains { $0.contains(value) }
    }

    var isAscii: Bool {
        value < 0x80
    }
}

private let zeroWidthJoiner: Unicode.Scalar = "\u{200D}"

/// East Asian Wide and Fullwidth, minus the ranges that are entirely emoji — those are caught by
/// `Emoji_Presentation` first, and are measured for real regardless.
private let wideRanges: [ClosedRange<UInt32>] = [
    0x1100...0x115F,   // Hangul jamo, initial consonants
    0x2E80...0x303E,   // CJK radicals, Kangxi radicals, CJK symbols and punctuation
    0x3041...0x33FF,   // kana, Hangul compatibility jamo, CJK compatibility
    0x3400...0x4DBF,   // CJK unified ideographs, extension A
    0x4E00...0x9FFF,   // CJK unified ideographs
    0xA000...0xA4CF,   // Yi syllables and radicals
    0xA960...0xA97F,   // Hangul jamo, extended A
    0xAC00...0xD7A3,   // Hangul syllables
    0xF900...0xFAFF,   // CJK compatibility ideographs
    0xFE10...0xFE19,   // vertical forms
    0xFE30...0xFE6B,   // CJK compatibility forms, small form variants
    0xFF01...0xFF60,   // fullwidth forms
    0xFFE0...0xFFE6,   // fullwidth signs
    0x17000...0x18CD5, // Tangut
    0x1B000...0x1B2FB, // kana supplement, kana extended
    0x20000...0x3FFFD  // CJK unified ideographs, extension B onwards
]

/// Scripts where the rendered advance is not the sum of its scalars: Arabic and Syriac join, Indic
/// and Thai reorder and stack.
private let reshapingScriptRanges: [ClosedRange<UInt32>] = [
    0x0590...0x08FF,   // Hebrew, Arabic, Syriac, Thaana, N'Ko, Samaritan, Arabic extended A
    0x0900...0x0DFF,   // Devanagari through Sinhala
    0x0E00...0x0EFF,   // Thai, Lao
    0x1F1E6...0x1F1FF  // regional indicators — two scalars render as one flag
]

private let variationSelectorRanges: [ClosedRange<UInt32>] = [
    0xFE00...0xFE0F,  // variation selectors 1 to 16
    0xE0100...0xE01EF // variation selectors supplement
]
