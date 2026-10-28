import Foundation
import Synchronization

import ClientViewerDomain

/// A lexer that answers with the lines it was given, and records every question it was asked.
///
/// **The questions are what most of the highlighting suite asserts.** `SPEC.md` §10's rules are about
/// *which* sides are lexed, in what order, and how often — never about what a keyword looks like — so
/// the assertion is the request that left the model rather than the colour that came back.
///
/// What it answers with is each line as its own text, unstyled. That is enough to prove the split,
/// the side and the indexing back onto line numbers, and it keeps this suite from asserting a theme
/// it does not own.
final class FakeSyntaxHighlighter: SyntaxHighlighter {

    /// Every side handed over, in order.
    var requests: [HighlightRequest] { asked.withLock { $0 } }

    /// A lexer that cannot read this text at all, which is every real failure: an unknown language, a
    /// JavaScript context that would not build, a bundle without that grammar in it.
    private let refuses: Bool

    /// A lexer that answers with one line fewer than it was given, which is the corruption
    /// `HighlightSource.indexed` refuses the whole answer over.
    private let dropsALine: Bool
    private let holdingFirstHighlight: Bool

    private let asked = Mutex<[HighlightRequest]>([])
    private let firstHighlightStarted = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    private let firstHighlightReleased = AsyncStream<Void>.makeStream()

    init(refuses: Bool = false, dropsALine: Bool = false, holdingFirstHighlight: Bool = false) {
        self.refuses = refuses
        self.dropsALine = dropsALine
        self.holdingFirstHighlight = holdingFirstHighlight
    }

    func waitUntilFirstHighlightIsSuspended() async {
        for await _ in firstHighlightStarted.stream { break }
    }

    func releaseFirstHighlight() {
        firstHighlightReleased.continuation.finish()
    }

    func highlight(
        _ text: String,
        as language: String,
        for appearance: HighlightAppearance,
        themed theme: CodeTheme
    ) async -> [AttributedString]? {
        let isFirst = asked.withLock {
            $0.append(
                HighlightRequest(text: text, language: language, appearance: appearance, theme: theme)
            )
            return $0.count == 1
        }
        if holdingFirstHighlight && isFirst {
            firstHighlightStarted.continuation.yield(())
            firstHighlightStarted.continuation.finish()
            for await _ in firstHighlightReleased.stream { break }
            guard Task.isCancelled == false else { return nil }
        }
        guard refuses == false else { return nil }
        let lines = text.components(separatedBy: "\n").map(AttributedString.init)
        return dropsALine ? Array(lines.dropLast()) : lines
    }
}

// MARK: -

/// One side of one file, as it reached the lexer.
struct HighlightRequest: Hashable, Sendable {

    let text: String
    let language: String
    let appearance: HighlightAppearance
    let theme: CodeTheme
}
