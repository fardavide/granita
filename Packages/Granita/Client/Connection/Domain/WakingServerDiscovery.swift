/// A browse that wakes the Macs this phone already knows before waiting to hear from them.
///
/// **A sleeping Mac is not a Mac that answers slowly — it is one that is not on the network at
/// all.** Since macOS 15 withdrew the sleep-proxy client, a Mac that dozes off takes its Bonjour
/// advertisement with it, so the browse this decorates would search an empty network and report
/// exactly that: nothing found, no row to tap, and no way for the reader to tell a Mac that is
/// asleep from one that is switched off.
///
/// **The wake happens at the browse, and that is what keeps it off any screen.** The alternative —
/// a row for a Mac that is asleep, with something to press — is a state design §1 does not have and
/// could not get without frames. Waking here means a sleeping Mac simply appears in the list a few
/// seconds later, through the states the discovery screen already draws, and the reader is told
/// nothing they would have to act on.
///
/// **It never delays, degrades or filters the browse it wraps.** The wake runs beside the stream,
/// not in front of it: a Keychain that will not answer, or a network that will not take a datagram,
/// must not cost the reader the Macs that are awake and were always going to be found.
public struct WakingServerDiscovery: ServerDiscovering {

    private let discovery: any ServerDiscovering
    private let macs: any RememberedMacStore
    private let waking: any MacWaking

    public init(discovery: any ServerDiscovering, macs: any RememberedMacStore, waking: any MacWaking) {
        self.discovery = discovery
        self.macs = macs
        self.waking = waking
    }

    public func discover() -> AsyncStream<DiscoveryState> {
        let discovery = discovery
        let macs = macs
        let waking = waking
        return AsyncStream { continuation in
            let waker = Task {
                // Silent on refusal, and the silence is the design. A Keychain that will not
                // enumerate costs the reader a wake they cannot perceive the absence of; reporting
                // it would put a Keychain error on the one screen whose job is to list Macs.
                guard let addresses = try? await macs.wakeAddresses(), addresses.isEmpty == false else { return }
                await waking.wake(addresses)
            }
            let browsing = Task {
                for await state in discovery.discover() {
                    continuation.yield(state)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                waker.cancel()
                browsing.cancel()
            }
        }
    }
}
