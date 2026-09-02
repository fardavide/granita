import Foundation

import CoreDiffDomain

/// Whether a row was added, removed, or neither — the `+`/`−` column's whole vocabulary.
///
/// `unchanged` rather than `none`, which would shadow `Optional.none` at every call site that also
/// handles an optional line.
public enum DiffMarker: Hashable, Sendable {
    case added
    case removed
    case unchanged
}

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

    /// The `+`/`−` column, between the figures and the code.
    ///
    /// A glyph rather than a run of colour, and at full saturation: the review's rule 2 moves the
    /// strongest colour in a row out from *behind* the code and into the marker, which is what frees
    /// the row tint to be almost nothing. Fixed rather than derived from the point size — one
    /// character of SF Mono at 11pt is 6.6pt and the column is 12, because the glyph is centred in it
    /// and a `−` that shifts as the code size changes stops being a column.
    public static let markerWidth: CGFloat = 12

    /// Between the marker and the first character of code.
    ///
    /// **The glyph is centred in a 12pt column, so a line with no leading whitespace starts about
    /// 2.7pt after it** — near enough to touching that `−public struct` read as one token, which is
    /// the opposite of what a marker at full saturation is for. Design §4 puts the code's origin at
    /// 48pt over a 30pt figure column and a 12pt marker, and this is the six points that arithmetic
    /// has always implied.
    ///
    /// Spacing rather than text, for the reason `trailingSpace` is: the gap wants to stay a gap when
    /// the code size changes.
    public static let markerTrailingSpace: CGFloat = 6

    /// Which side's number a row shows, in the one column that now carries both.
    ///
    /// **A deletion shows the old side and everything else shows the new**, which is what makes the
    /// column never empty. Before this, the gutter held the new-side number alone and a deletion drew
    /// a blank — the review's first fault, and the only one it called a correctness bug.
    ///
    /// Nothing falls back to the other side when its own is absent. A deletion with no old number is
    /// not something the parser produces, and a row quietly showing the number of the side it is not
    /// on is the misreading the whole column exists to prevent.
    public static func number(of line: DiffLine) -> Int? {
        switch line.kind {
        case .deletion: line.oldNumber
        case .addition, .context: line.newNumber
        // **A conflict marker is a real line and it is numbered.** The parser resolves the kind from
        // the *text* but takes the numbers from the diff prefix the line arrived with, so a
        // `<<<<<<<` that came through as context carries both numbers and one that came through as
        // an addition carries the new one. Whichever it has is the one to show; blanking these would
        // put the empty gutter back on the rows a reader most needs to point at.
        case .conflictMarker: line.newNumber ?? line.oldNumber
        // Not a line of the file at all. `\ No newline at end of file` is git's own annotation, and
        // numbering it would claim the file has a line it does not.
        case .noNewlineMarker: nil
        }
    }

    /// Which glyph stands beside the figure.
    ///
    /// The exhaustive answer matters more here than the two obvious cases: `SPEC.md` §5.3 makes a
    /// conflict marker an ordinary diff line with its own kind, and it is neither side of the
    /// comparison. The no-`default:` rule is what forces that to be decided rather than defaulted
    /// into a `+`.
    public static func marker(of line: DiffLine) -> DiffMarker {
        switch line.kind {
        case .addition: .added
        case .deletion: .removed
        case .context, .noNewlineMarker, .conflictMarker: .unchanged
        }
    }
}
