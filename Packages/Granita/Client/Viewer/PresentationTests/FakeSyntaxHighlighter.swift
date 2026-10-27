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

    private let asked = Mutex<[HighlightRequest]>([])
    private let suspendsFirstRequest: Bool
    private let requestStarted: AsyncStream<Void>
    private let requestStartedContinuation: AsyncStream<Void>.Continuation
    private let suspendedHighlighting: AsyncStream<Void>
    private let suspendedHighlightingContinuation: AsyncStream<Void>.Continuation

    init(refuses: Bool = false, dropsALine: Bool = false, suspendingFirstRequest: Bool = false) {
        self.refuses = refuses
        self.dropsALine = dropsALine
        suspendsFirstRequest = suspendingFirstRequest
        let started = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        requestStarted = started.stream
        requestStartedContinuation = started.continuation
        let suspended = AsyncStream<Void>.makeStream()
        suspendedHighlighting = suspended.stream
        suspendedHighlightingContinuation = suspended.continuation
    }

    func waitUntilAsked() async {
        var events = requestStarted.makeAsyncIterator()
        _ = await events.next()
    }

    func resumeHighlighting() {
        suspendedHighlightingContinuation.finish()
    }

    func highlight(
        _ text: String,
        as language: String,
        for appearance: HighlightAppearance,
        themed theme: CodeTheme
    ) async -> [AttributedString]? {
        let ordinal = asked.withLock {
            $0.append(
                HighlightRequest(text: text, language: language, appearance: appearance, theme: theme)
            )
            return $0.count
        }
        requestStartedContinuation.yield(())
        if suspendsFirstRequest && ordinal == 1 {
            var events = suspendedHighlighting.makeAsyncIterator()
            _ = await events.next()
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
