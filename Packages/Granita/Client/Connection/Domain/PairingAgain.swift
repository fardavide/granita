public struct PairingAgain: Hashable, Sendable {
    public let server: DiscoveredServer

    public init(server: DiscoveredServer) {
        self.server = server
    }
}
