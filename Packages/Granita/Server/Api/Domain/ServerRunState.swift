import ServerStoreDomain

/// Where the server is reachable, as the menu bar reports it.
///
/// The port is not always ours to choose: a Bonjour bind hands the choice to the system and
/// publishes what it chose, so this is what the server ended up on rather than what it asked for.
public struct ServerEndpoint: Hashable, Sendable {

    public let host: String
    public let port: Int

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
}

/// What the server is doing, as the menu bar item draws it.
public enum ServerRunState: Hashable, Sendable {

    /// Binding, or rebinding after the Mac woke up.
    case starting

    case running(ServerEndpoint)

    /// It could not bind or could not stay up, and this is why.
    ///
    /// Carries the reason because the person who can act on it is standing at the Mac, and because
    /// the alternative — an icon that means "something is wrong" — is what makes someone reach for
    /// a debugger over a menu.
    case failed(reason: String)

    /// Not serving, and not trying to.
    case stopped

    /// Another process holds this Mac's settings, so this one never started — SPEC §9's lock file,
    /// and the second process to start is the one that refuses.
    ///
    /// **A state of its own rather than a `failed` carrying a different sentence**, because the two
    /// have opposite answers. Everything else that reaches `failed` is a bind that did not happen,
    /// and General's advice there is Local Network access — which for this is a settings pane that
    /// is already correct, and a reader sent to check it learns nothing and comes back. Here the
    /// thing to do is quit the other process, so the row names it.
    ///
    /// The holder is optional because the refusal outlives the name: see ``StoreLockOutcome``.
    case blockedByAnotherProcess(StoreLockHolder?)
}

/// Runs the API server for as long as it is asked to, reporting what it is doing.
///
/// The menu bar app embeds the same backend the executable runs, so this is the seam between "the
/// server" and "the app that shows it": a view model follows the states, and a test follows them
/// without binding a port.
public protocol ServerHosting: Sendable {

    /// Runs until the surrounding task is cancelled, reporting every state it reaches.
    func run() -> AsyncStream<ServerRunState>
}
