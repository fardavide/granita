import Foundation

import CoreDiffDomain

/// One file's lexed text, filed by the number each line sits at on the side it came from.
///
/// **Two sides rather than one, because a diff is two files drawn interleaved.** The old side and
/// the new side are lexed separately — that is `SPEC.md` §10's rule and the reason for it — so a
/// deletion and the addition replacing it are coloured from two different answers, and the row is
/// what decides which. Merging them into one map would file two different lines under one number.
///
/// **What a line *is* here is an `AttributedString` and nothing more specific**, which keeps the
/// question of what a colour looks like in the view layer where the theme lives. This type knows
/// which line an answer belongs to and nothing about what it says.
public struct HighlightedFile: Hashable, Sendable {

    /// Nothing lexed yet, which is what every file draws until its first answer lands and what a
    /// refused one draws forever.
    public static let none = HighlightedFile(old: [:], new: [:])

    private let old: [Int: AttributedString]
    private let new: [Int: AttributedString]

    public init(old: [Int: AttributedString], new: [Int: AttributedString]) {
        self.old = old
        self.new = new
    }

    /// The same file with one side's answer put in, leaving the other exactly as it was.
    ///
    /// **A replacement rather than a merge.** A side is lexed as one string, so what comes back is
    /// the whole of that side's answer — and after a hunk expansion it is a *different* whole, lexed
    /// against a wider string. Merging would leave lines from the narrower lex sitting under numbers
    /// the wider one has since re-decided.
    public func replacing(_ side: DiffSide, with lines: [Int: AttributedString]) -> HighlightedFile {
        switch side {
        case .old: HighlightedFile(old: lines, new: new)
        case .new: HighlightedFile(old: old, new: lines)
        }
    }

    /// What this row's code was lexed as, or nothing when it was not.
    ///
    /// **The row asks the side it is on, and never the other one.** A deletion has only an old
    /// number and an addition only a new one, so there is exactly one side to ask; a context line has
    /// both and is read from the new, which is the file as it stands. `DiffGutter.number(of:)` makes
    /// the same call for the figure it draws and refuses the same fallback, for the same reason — a
    /// row quietly showing the other side's answer is a misreading that looks entirely convincing.
    ///
    /// Nothing at all for a conflict marker or git's no-newline annotation. A marker is numbered and
    /// still never lexed — `SyntaxHighlighting` drops it by kind — so nothing is filed under the
    /// number it carries and it draws in §4's own tint at semibold, which is what says what it is.
    public func text(of line: DiffLine) -> AttributedString? {
        if let number = line.newNumber {
            return new[number]
        }
        if let number = line.oldNumber {
            return old[number]
        }
        return nil
    }
}
