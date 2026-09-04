import Highlightr
import SwiftUI

import ClientViewerDomain

/// The one lexer in the app: highlight.js in a JavaScript context, behind an actor that owns it.
///
/// **One instance for the app's lifetime, on one actor.** `JSContext` is not shareable across
/// threads, and building one loads and evaluates the whole highlight.js bundle — about 100ms. So the
/// engine is created on first use rather than at launch, and it never leaves this actor.
///
/// **The theme is switched rather than a second engine built.** An appearance is a different set of
/// colours over the same lexer, and re-parsing one stylesheet is a regular expression over a few
/// kilobytes where a second engine is another JavaScript context.
///
/// **`nonisolated(unsafe)` is not used and no `@unchecked Sendable` is claimed.** The engine is a
/// stored property of an actor, which is what makes serial access a fact rather than a promise.
public actor HighlightrSyntaxHighlighter: SyntaxHighlighter {

    /// The two stylesheets, and they are Xcode's own.
    ///
    /// **Chosen because the reader is looking at code they wrote in Xcode.** Granita's design
    /// language is Apple's throughout and the phone is beside the Mac the diff came from, so the
    /// colours that already mean *keyword* and *string* to this reader are the ones Xcode gave them.
    /// They are also the most muted of the credible pairs, which matters more here than in an editor:
    /// a row already carries an add or remove tint and a word-diff background at three times it, and
    /// `design.md` §4's whole argument is that those stay the loudest thing in the row.
    ///
    /// **Not yet a setting**, and that is filed rather than forgotten:
    /// [#70](https://github.com/fardavide/granita/issues/70).
    static func theme(for appearance: HighlightAppearance) -> String {
        switch appearance {
        case .light: "xcode"
        case .dark: "xcode-dark"
        }
    }

    private var engine: Highlightr?

    /// Whether building the engine has been attempted, so a machine that cannot build one is not
    /// asked to try again for every side of every file.
    private var hasBuiltEngine = false

    /// Which stylesheet is loaded, so an unchanged appearance does not re-parse one.
    private var loadedTheme: String?

    /// What this build of highlight.js can actually lex.
    ///
    /// **Read once and asked before every call, which is a guard rather than an optimisation.**
    /// Highlightr assigns the result of `invokeMethod` to a non-optional `JSValue`, and highlight.js
    /// v11 *throws* for a language it does not know — so an unrecognised name is a crash inside the
    /// dependency rather than the fallback its own code appears to offer.
    ///
    /// **Nothing reaches it today**, and it is kept anyway: this build registers 192 grammars,
    /// including every name `LanguageHint` can produce from a file extension. What it protects
    /// against is one more line in that table, or a Highlightr that ships a smaller bundle — and the
    /// cost of being wrong about either is a crash rather than a plain-rendered file.
    private var lexableLanguages: Set<String>?

    public init() {}

    public func highlight(
        _ text: String,
        as language: String,
        for appearance: HighlightAppearance
    ) async -> [AttributedString]? {
        // **One branch for three refusals, because they are one outcome.** A JavaScript context that
        // would not build, a grammar this bundle does not carry and a lexer that answered with
        // nothing all leave the side rendering as plain monospaced text, which is the state
        // `SPEC.md` §10 makes every side start in. None of the three is reachable from a rendered
        // baseline, so writing them as one guard is also the honest denominator.
        guard let engine = engine(themed: appearance),
              lexable(language, by: engine),
              let lexed = engine.highlight(text, as: language, fastRender: true) else {
            return nil
        }
        return lines(of: lexed)
    }

    // MARK: -

    /// The engine with the right stylesheet on it, or nothing at all on a machine that cannot build
    /// one.
    private func engine(themed appearance: HighlightAppearance) -> Highlightr? {
        if hasBuiltEngine == false {
            hasBuiltEngine = true
            engine = Highlightr()
        }
        let wanted = Self.theme(for: appearance)
        if loadedTheme != wanted {
            loadedTheme = wanted
            // Optional-chained rather than guarded: a machine with no JavaScript context has already
            // lost, and the caller's own guard says so once. A second branch here would be the same
            // failure written twice.
            engine?.setTheme(to: wanted)
        }
        return engine
    }

    private func lexable(_ language: String, by engine: Highlightr) -> Bool {
        let known = lexableLanguages ?? Set(engine.supportedLanguages())
        lexableLanguages = known
        return known.contains(language)
    }

    /// The lexed string cut back into the lines it was joined from, carrying colour and nothing else.
    ///
    /// **Only the foreground colour survives, and dropping the rest is the whole join with §4.** The
    /// theme also asks for a font — Courier at 14pt, which every row's height is not — and for
    /// background colours on three of its classes, which would sit under the word-diff background
    /// that `SPEC.md` §10 makes the strongest thing in a row. A lexer colours text here and does
    /// nothing else.
    ///
    /// **A newline starts a line whether or not there is anything on it**, so a blank line stays in
    /// the count rather than disappearing from it — a side one line short is one where every colour
    /// after the gap lands on the wrong row, which is what `HighlightSource.indexed` refuses the
    /// whole answer over.
    private func lines(of lexed: NSAttributedString) -> [AttributedString] {
        let whole = lexed.string as NSString
        var lines = [AttributedString()]
        lexed.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: lexed.length),
            options: []
        ) { value, range, _ in
            // Through `CGColor` rather than through `Color(uiColor:)`, which is the one spelling that
            // is the same on both platforms: this package builds for the host so `make test` needs no
            // simulator, and a `#if` here would be a branch that only ever runs on one of them.
            let colour = (value as? RPColor).map { Color(cgColor: $0.cgColor) }
            for (offset, piece) in whole.substring(with: range).components(separatedBy: "\n").enumerated() {
                if offset > 0 {
                    lines.append(AttributedString())
                }
                guard piece.isEmpty == false else { continue }
                var run = AttributedString(piece)
                run.foregroundColor = colour
                lines[lines.count - 1].append(run)
            }
        }
        return lines
    }
}
