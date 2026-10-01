/// The remote choices stay available when a remembered Mac is asleep or on another network.
public struct MacSourceMenu: Hashable, Sendable {

    public let servers: [DiscoveredServer]
    public let status: DiscoveryState

    public init(discovery: DiscoveryState, remembered: [DiscoveredServer], excluding instance: BonjourInstanceName) {
        var byIdentity: [BonjourInstanceName: DiscoveredServer] = [:]
        for server in remembered {
            byIdentity[server.id] = server
        }
        if case .found(let discovered) = discovery {
            for server in discovered {
                byIdentity[server.id] = server
            }
        }
        byIdentity.removeValue(forKey: instance)
        servers = byIdentity.values.sorted { $0.name < $1.name }
        switch discovery {
        case .idle: status = .searching
        case .found: status = .found(servers)
        case .searching, .localNetworkDenied, .failed: status = discovery
        }
    }
}
