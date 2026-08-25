import Foundation

/// How wide a line-number column is, and design §4's argument for why the phone gets one of them.
///
/// **The width is per file, from that file's own highest line number.** One width for the whole
/// scroll would size every gutter for the largest file in the change set, and a 200-line file would
/// pay four figures of it for numbers it never shows — eight characters of code, at the width where
/// §4 measures 51 of them. Per file, the column is as wide as the numbers going in it and no wider.
///
/// The numbers here are §4's: SF Mono advances six tenths of its point size, a four-figure number is
/// therefore 26.4pt at 11pt, and with 4pt of leading inset and 9pt of trailing space one column is
/// 39pt. Two are 78, which is why the phone keeps only the new one.
public enum DiffGutter {

    /// What one character costs, as a fraction of the point size.
    ///
    /// The one number in this file that came from measuring a font rather than from adding two
    /// others up. It holds for SF Mono at every size, which is what lets the code size be a setting
    /// rather than a constant.
    public static let advanceRatio: CGFloat = 0.6

    /// Between the leading edge and the first figure.
    public static let leadingInset: CGFloat = 4

    /// Between the last figure and the code. Spacing rather than text, so it does not scale with
    /// the point size — the gap wants to stay a gap.
    public static let trailingSpace: CGFloat = 9

    public static func advanceWidth(atPointSize pointSize: CGFloat) -> CGFloat {
        pointSize * advanceRatio
    }

    /// The width of one column for a file whose largest line number is `highest`.
    ///
    /// A file with nothing on that side — the new column of a deleted file, whose every row is
    /// blank — still gets one figure's worth, because the alternative is the first character of
    /// code against the edge on exactly the rows that have no number to align to.
    public static func columnWidth(forHighestLineNumber highest: Int, atPointSize pointSize: CGFloat) -> CGFloat {
        let figures = max(1, String(max(0, highest)).count)
        return leadingInset + CGFloat(figures) * advanceWidth(atPointSize: pointSize) + trailingSpace
    }
}
