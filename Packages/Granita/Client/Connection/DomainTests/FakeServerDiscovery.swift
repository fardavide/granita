import ClientConnectionDomain

struct FakeServerDiscovery: ServerDiscovering {

    let states: [DiscoveryState]

    func discover() -> AsyncStream<DiscoveryState> {
        AsyncStream { continuation in
            for state in states { continuation.yield(state) }
            continuation.finish()
        }
    }
}
