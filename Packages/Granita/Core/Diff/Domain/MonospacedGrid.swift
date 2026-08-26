import Foundation

/// The grid the viewer's monospaced text sits on, and the one place that decides how wide a tab is.
///
/// **It is public because the client has to draw what this measured.** `displayColumns` travels on
/// every diff line so the scroll can reserve space before laying anything out, and it is computed
/// with tabs expanded to the stop below. A view that then handed the raw string to a text engine
/// would get that engine's own tab stops — which are a function of the font, not of this number — so
/// a tab-indented file would draw at one width and be measured at another. The two sides
/// re-deriving the same judgement is the trap `SPEC.md` §6 keeps this arithmetic on the server to
/// avoid; the answer is not to re-derive it here either, but to expand from the same constant.
public enum MonospacedGrid {

    /// Four, which is what this repository's own Swift is indented with, and the number
    /// `displayColumns` was computed against.
    public static let tabStop = 4

    /// The line as it must be drawn: every tab replaced by the spaces that reach the next stop.
    ///
    /// Counted in **columns rather than characters**, so a tab after a CJK ideograph advances from
    /// two rather than from one. Returns the line untouched when it holds no tab, which is nearly
    /// every line of nearly every file.
    public static func expandingTabs(in text: String) -> String {
        guard text.contains("\t") else { return text }
        var expanded = ""
        var columns = 0
        for character in text {
            guard character == "\t" else {
                expanded.append(character)
                columns += DisplayWidth(of: String(character)).columns
                continue
            }
            let filling = tabStop - columns % tabStop
            expanded.append(String(repeating: " ", count: filling))
            columns += filling
        }
        return expanded
    }
}
