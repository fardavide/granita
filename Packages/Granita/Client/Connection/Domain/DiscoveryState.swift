/// What the phone currently knows about Granita servers nearby.
///
/// `localNetworkDenied` is a first-class case rather than a flavour of failure because it is the
/// one the user can fix, and because it is guaranteed to happen at least once: iOS requires explicit
/// permission before an app may browse the local network, and a denial is silent otherwise —
/// browsing simply never yields anything.
public enum DiscoveryState: Hashable, Sendable {
    case idle
    case searching
    case found([DiscoveredServer])
    case localNetworkDenied

    /// A fault that is not a refusal, carrying what the system said about it.
    ///
    /// The payload is a **diagnostic**, not advice, and the label says so: the screen writes its own
    /// description and prints this underneath in small print. Handing a framework's own sentence to
    /// the one line a reader will act on makes the advice whatever Network.framework felt like
    /// saying, which is "the operation couldn't be completed" — true of every failure there has ever
    /// been, and actionable in none of them.
    case failed(diagnostic: String)
}

/// Browses the local network for Granita servers.
///
/// Implemented over Bonjour in the Data layer. Modelled as a stream rather than a one-shot lookup
/// because servers appear and disappear while the screen is open — a Mac waking from sleep is the
/// common case.
public protocol ServerDiscovering: Sendable {
    func discover() -> AsyncStream<DiscoveryState>
}
