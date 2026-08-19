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
    case failed(String)
}

/// Browses the local network for Granita servers.
///
/// Implemented over Bonjour in the Data layer. Modelled as a stream rather than a one-shot lookup
/// because servers appear and disappear while the screen is open — a Mac waking from sleep is the
/// common case.
public protocol ServerDiscovering: Sendable {
    func discover() -> AsyncStream<DiscoveryState>
}
