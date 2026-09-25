/// Which permission the reader has to change, for the platforms where that is a separate place.
///
/// **It exists because of the Mac and would have been noise without one.** iOS gives an app a single
/// page carrying every switch it has asked for, so all three screens that offer this wanted the same
/// destination and the act was written once with nothing to choose. macOS has no such page — Local
/// Network and Camera are two panes of Privacy & Security — so a Mac that ignored the difference would
/// send a reader whose *camera* is off to a Local Network switch, answered by a button that appeared
/// to work.
public enum SystemSettingsPane: Hashable, Sendable {
    case camera
    case localNetwork
}

/// Opening the pane where the reader can grant what a screen just said was missing.
///
/// **A seam rather than a free function in a screen**, which is where this used to live. It had a
/// comment excusing itself — *"it hands a URL the system owns to the system and is told nothing back,
/// so there is nothing for a fake to stand in for"* — and that was true of the act and false of the
/// decision beside it. Which URL is a real choice with a real wrong answer, it became a choice the day
/// the Client gained a Mac destination, and the failure it can produce is silent: a mistyped scheme or
/// extension identifier opens System Settings on its front page, which looks exactly like the app
/// working and leaves the reader hunting for a pane nobody named.
///
/// **Fire and forget, and it does not answer.** `NSWorkspace.open` reports whether the URL was handed
/// over, not whether a pane appeared, and there is nothing any screen here would do differently either
/// way — so this shares the shape of `DiagnosticLogsCopying` beside it rather than returning something
/// no state could draw.
public protocol SystemSettingsOpening: Sendable {

    /// **On the main actor, because both implementations of it are.** `NSWorkspace.shared` and
    /// `UIApplication.shared` are main-actor isolated, and a nonisolated requirement let the one
    /// conformer that touches them reach both from a nonisolated method — two warnings that Swift 6
    /// promotes to errors, on the act behind a control a reader presses. Stated here rather than
    /// asserted at the call site or hopped onto with a `Task`, so the compiler holds it: every caller
    /// is a screen, the act stays synchronous, and nothing can call this from somewhere it would be
    /// a race.
    @MainActor
    func open(_ pane: SystemSettingsPane)
}
