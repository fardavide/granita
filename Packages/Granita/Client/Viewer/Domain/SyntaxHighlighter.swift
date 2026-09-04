import Foundation

/// Whatever turns one side of a file into coloured lines.
///
/// **One string in, one line per newline out** — the split is the highlighter's rather than the
/// caller's, because a lexer that answers with a different number of lines than it was given is a
/// fact `HighlightSource.indexed` needs in order to refuse the whole answer. Filing the result under
/// the numbers the gutter draws is the caller's job and nothing here knows about it.
///
/// **Nothing is thrown.** Every failure a lexer has is the same outcome — the side renders as plain
/// monospaced text, which is the state `SPEC.md` §10 makes every side start in — so a refusal is
/// `nil` rather than an error nobody would branch on.
///
/// `async` because the work is a JavaScript engine behind a bridge and belongs off the main actor,
/// which is the whole reason `SPEC.md` §2 rules out the obvious library for this.
public protocol SyntaxHighlighter: Sendable {

    /// The lines of `text`, coloured for `appearance`, or nothing when this text cannot be lexed.
    func highlight(
        _ text: String,
        as language: String,
        for appearance: HighlightAppearance
    ) async -> [AttributedString]?
}
