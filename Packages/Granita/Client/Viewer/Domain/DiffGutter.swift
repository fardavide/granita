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
    ///
    /// **Real drawn space rather than arithmetic**, which is what design §7's comment rail is built
    /// on: a figure is trailing-aligned in a frame this much wider than the figures themselves, so
    /// even the file's own longest number leaves these four points empty at the leading edge. Three
    /// of them are the rail. Nothing else on the row was carrying nothing.
    public static let leadingInset: CGFloat = 4

    /// The mark a commented run draws, in the leading inset rather than in the figure column.
    ///
    /// **Design §7's call 7.** The alternatives each cost something the gutter cannot give up: a
    /// glyph replacing the figure re-opens the diff review's first fault, which is the only one it
    /// called a correctness bug; a row tint collides with the `+`/`−` tints and the word-diff
    /// background, which is already the strongest colour in the row; and a pin at the trailing edge
    /// costs two characters of code on every row of every file, forever, to mark four of them.
    ///
    /// Length is what says how long the run is — 18pt for one row and 72 for four — so a run reads
    /// without a count, without colour, and without a single point of new height.
    public static let railWidth: CGFloat = 3

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

    /// Everything to the left of the first character of code, which is the strip a comment is aimed
    /// at.
    ///
    /// **The figures, the marker, and the space after it** — all three already sit outside the
    /// per-hunk horizontal scroll, so taking them together costs nothing and buys the difference
    /// between a 20pt target and a 51pt one. Design §7 measures the ordinary case at about 51pt and
    /// the narrowest a change set can produce — a file with nine lines in it — at about 38.
    ///
    /// It is the width of a *target*, not of a control: `GutterTarget` resolves a touch anywhere in
    /// it to the nearest numbered row, so there is no boundary in it to land inside and no dead space
    /// to land in.
    public static func tapStripWidth(forHighestLineNumber highest: Int, atPointSize pointSize: CGFloat) -> CGFloat {
        columnWidth(forHighestLineNumber: highest, atPointSize: pointSize) + markerWidth + markerTrailingSpace
    }

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
