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

    private var engine: Highlightr?

    /// Whether building the engine has been attempted, so a machine that cannot build one is not
    /// asked to try again for every side of every file.
    private var hasBuiltEngine = false

    /// Which stylesheet is loaded, so an unchanged pair does not re-parse one.
    ///
    /// **A theme change costs exactly one `setTheme`, which is what makes five pairs affordable.** The
    /// guard was here before the setting was, for the appearance; a theme is the same question asked
    /// about the other half of the pair.
    private var loadedStylesheet: String?

    /// What each stylesheet draws text it did not classify in, learned once and kept.
    ///
    /// **Probed rather than read, because Highlightr does not expose it.** `Theme` publishes
    /// `themeBackgroundColor` and keeps the `.hljs` foreground in a private dictionary, so the only
    /// way to the base colour is to ask the lexer for a token no grammar classifies and see what comes
    /// back. One space, once per stylesheet, and the answer is cached for the life of the actor —
    /// which is the life of the app.
    ///
    /// Doubly optional on purpose: the outer is *have we asked*, the inner is *did it answer*. A
    /// stylesheet with no `.hljs` colour rule at all is a real case, and collapsing the two would
    /// re-probe it on every side of every file.
    ///
    /// Keyed by stylesheet and language together — see `base(of:as:by:)` for why the grammar is part of
    /// the question.
    private var baseColours: [String: Color?] = [:]

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
        for appearance: HighlightAppearance,
        themed theme: CodeTheme
    ) async -> [AttributedString]? {
        let stylesheet = theme.stylesheet(for: appearance)
        // **One branch for three refusals, because they are one outcome.** A JavaScript context that
        // would not build, a grammar this bundle does not carry and a lexer that answered with
        // nothing all leave the side rendering as plain monospaced text, which is the state
        // `SPEC.md` §10 makes every side start in. None of the three is reachable from a rendered
        // baseline, so writing them as one guard is also the honest denominator.
        guard let engine = engine(styled: stylesheet),
              lexable(language, by: engine),
              let lexed = engine.highlight(text, as: language, fastRender: true) else {
            return nil
        }
        return lines(of: lexed, over: base(of: stylesheet, as: language, by: engine))
    }

    // MARK: -

    /// The engine with the right stylesheet on it, or nothing at all on a machine that cannot build
    /// one.
    private func engine(styled stylesheet: String) -> Highlightr? {
        if hasBuiltEngine == false {
            hasBuiltEngine = true
            engine = Highlightr()
        }
        if loadedStylesheet != stylesheet {
            loadedStylesheet = stylesheet
            // Optional-chained rather than guarded: a machine with no JavaScript context has already
            // lost, and the caller's own guard says so once. A second branch here would be the same
            // failure written twice.
            engine?.setTheme(to: stylesheet)
        }
        return engine
    }

    /// What this stylesheet colours unclassified text, asked once.
    ///
    /// **A single space, because whitespace at the top level is inside no span in any grammar**, so
    /// what comes back carries the `.hljs` rule's colour and nothing else. Anything more interesting
    /// risks being a token some grammar has an opinion about, which would freeze a *classified* colour
    /// as the base and then strip it from every run that used it.
    ///
    /// **Lexed as the language in hand rather than with `nil`, and that distinction is the whole
    /// correctness of this probe.** Passing `nil` asks Highlightr to detect a language, and detection
    /// over one space picks something arbitrary whose top-level scope may carry a class of its own —
    /// so the "base" came back as that class's colour and every run legitimately using it lost its
    /// own. Measured on `github-dark`, where it stripped the colour from every keyword in the file.
    ///
    /// Keyed on the pair, because the answer is a property of the stylesheet *and* of the grammar that
    /// produced the run — two languages under one stylesheet can disagree about what is unclassified.
    private func base(of stylesheet: String, as language: String, by engine: Highlightr) -> Color? {
        let key = "\(stylesheet)|\(language)"
        if let known = baseColours[key] { return known }
        let probed = engine.highlight(" ", as: language, fastRender: true)
            .flatMap { $0.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? RPColor }
            .map { Color(cgColor: $0.cgColor) }
        baseColours[key] = probed
        return probed
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
    ///
    /// **The stylesheet's base colour is dropped rather than carried**, which is what lets a theme
    /// other than Xcode's ship at all. A run the lexer did not classify arrives holding the `.hljs`
    /// colour — near-black on Atom One, a grey on Stack Overflow — and handing that to the row would
    /// make a file the lexer accepted draw its plain text in a different colour from a file it
    /// refused, one scroll apart. Mapped to nothing, the row's own `.primary` draws it and the two
    /// agree. On Xcode it is a no-op: `#000000` and `#FFFFFF` are `label` to the byte in their
    /// appearances, which is the fact `design.md` §4 already relies on.
    private func lines(of lexed: NSAttributedString, over base: Color?) -> [AttributedString] {
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
            let lexedColour = (value as? RPColor).map { Color(cgColor: $0.cgColor) }
            let colour = lexedColour == base ? nil : lexedColour
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
