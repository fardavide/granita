/// A reader in the serving process must not discover a network route back to itself.
public struct ExcludingServerDiscovery: ServerDiscovering {

    private let discovery: any ServerDiscovering
    private let instance: BonjourInstanceName

    public init(discovery: any ServerDiscovering, instance: BonjourInstanceName) {
        self.discovery = discovery
        self.instance = instance
    }

    public func discover() -> AsyncStream<DiscoveryState> {
        AsyncStream { continuation in
            let task = Task {
                for await state in discovery.discover() {
                    switch state {
                    case .found(let servers):
                        let remote = servers.filter { $0.id != instance }
                        continuation.yield(remote.isEmpty ? .searching : .found(remote))
                    case .idle, .searching, .localNetworkDenied, .failed:
                        continuation.yield(state)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
