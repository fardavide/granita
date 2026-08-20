import Network

import ClientConnectionDomain

/// The part of a Bonjour browser this feature drives.
///
/// It exists so the session that replaces dead browsers can be tested without the three things a
/// host test cannot have: a network, a Mac, and a local network permission decision.
protocol ServiceBrowsing: Sendable {

    /// Begins browsing and reports everything that happens, ending when the browser stops for good.
    func start() -> AsyncStream<BrowserEvent>

    func cancel()
}

/// What a browser reports, in this feature's vocabulary rather than the network framework's.
enum BrowserEvent: Sendable {
    case ready
    /// Alive but unable to proceed. A waiting browser recovers on its own.
    case waiting(NWError)
    /// Dead. Nothing further arrives on a browser that reports this, and nothing revives it.
    case failed(NWError)
    case found([DiscoveredServer])
}
