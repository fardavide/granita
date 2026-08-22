import ClientConnectionDomain

/// Yields a fixed run of states and ends, which is what a browse that finds something and then
/// stops looks like from above.
struct FakeServerDiscovery: ServerDiscovering {

    let states: [DiscoveryState]

    func discover() -> AsyncStream<DiscoveryState> {
        AsyncStream { continuation in
            for state in states { continuation.yield(state) }
            continuation.finish()
        }
    }
}
