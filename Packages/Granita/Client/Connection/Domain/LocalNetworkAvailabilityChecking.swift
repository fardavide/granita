public enum LocalNetworkAvailability: Hashable, Sendable {
    case available
    case unavailable
}

public protocol LocalNetworkAvailabilityChecking: Sendable {
    func availability() async -> LocalNetworkAvailability
}
