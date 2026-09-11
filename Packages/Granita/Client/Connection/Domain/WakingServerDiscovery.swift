/// A browse that keeps the Macs this phone already knows reachable in the discovery list.
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
/// **Remembered rows outlive Bonjour.** A Mac with a stored direct address stays tappable when the
/// browse is empty or local-network permission is absent; opening it still tries Bonjour first and
/// only then uses that address. Keychain failures leave the wrapped browse unchanged.
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
            let remembering = Task {
                (try? await macs.rememberedMacs()) ?? []
            }
            let waker = Task {
                // Silent on refusal, and the silence is the design. A Keychain that will not
                // enumerate costs the reader a wake they cannot perceive the absence of; reporting
                // it would put a Keychain error on the one screen whose job is to list Macs.
                guard let addresses = try? await macs.wakeAddresses(), addresses.isEmpty == false else { return }
                await waking.wake(addresses)
            }
            let browsing = Task {
                for await state in discovery.discover() {
                    switch state {
                    case .found(let servers):
                        let remembered = await remembering.value
                        let found = Set(servers.map(\.id))
                        continuation.yield(.found(
                            servers + remembered
                                .filter { found.contains($0) == false }
                                .sorted { $0.rawValue < $1.rawValue }
                                .map { DiscoveredServer(id: $0, name: $0.rawValue) }
                        ))
                    case .localNetworkDenied:
                        let remembered = await remembering.value
                        guard remembered.isEmpty == false else {
                            continuation.yield(state)
                            continue
                        }
                        continuation.yield(.found(
                            remembered
                                .sorted { $0.rawValue < $1.rawValue }
                                .map { DiscoveredServer(id: $0, name: $0.rawValue) }
                        ))
                    case .idle, .searching, .failed:
                        continuation.yield(state)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                remembering.cancel()
                waker.cancel()
                browsing.cancel()
            }
        }
    }
}
