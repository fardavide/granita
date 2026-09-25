import Synchronization

import ClientConnectionDomain

/// **What is written down, kept**, because the rule under test is which arrivals count as opening a
/// Mac and which do not — and a fake that only answered reads could not tell the two apart.
///
/// A `Mutex` rather than an actor, for the reason the settings opener's fake uses one: none of these
/// calls is `async`, because the answer is needed before a frame is drawn, so a fake that had to be
/// awaited could not conform.
final class FakeLastOpenedMacPreference: LastOpenedMacPreference {

    private let stored: Mutex<DiscoveredServer?>

    var remembered: DiscoveredServer? {
        stored.withLock { $0 }
    }

    init(opened mac: DiscoveredServer? = nil) {
        stored = Mutex(mac)
    }

    func lastOpenedMac() -> DiscoveredServer? {
        stored.withLock { $0 }
    }

    func remember(_ mac: DiscoveredServer) {
        stored.withLock { $0 = mac }
    }

    func forget() {
        stored.withLock { $0 = nil }
    }
}
