import ClientConnectionDomain

actor FakeLegacyServerAddressResolving: ServerAddressResolving {
    private(set) var received: [DiscoveredServer] = []

    private let answering: Result<ServerAddress, ServerAddressResolutionFailure>

    init(answering: Result<ServerAddress, ServerAddressResolutionFailure>) {
        self.answering = answering
    }

    func address(of server: DiscoveredServer) throws(ServerAddressResolutionFailure) -> ServerAddress {
        received.append(server)
        switch answering {
        case .success(let address): return address
        case .failure(let failure): throw failure
        }
    }
}
