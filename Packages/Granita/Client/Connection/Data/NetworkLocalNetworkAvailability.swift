import Network

import ClientConnectionDomain

public struct NetworkLocalNetworkAvailability: LocalNetworkAvailabilityChecking {

    private let checking: @Sendable () async -> NWPath.Status

    public init() {
        checking = {
            // A VPN's generic path can be `.other` even over cellular. Check physical Wi-Fi,
            // not internet reachability or assumed proximity to the paired Mac.
            let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
            defer { monitor.cancel() }
            var iterator = monitor.makeAsyncIterator()
            return await iterator.next()?.status ?? .unsatisfied
        }
    }

    init(checking: @escaping @Sendable () async -> NWPath.Status) {
        self.checking = checking
    }

    public func availability() async -> LocalNetworkAvailability {
        await checking() == .satisfied ? .available : .unavailable
    }
}
