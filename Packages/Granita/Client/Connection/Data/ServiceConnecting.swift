import ClientConnectionDomain

/// The part of a Bonjour connection this feature drives.
///
/// It exists so the resolver above it can be tested without the three things a host test cannot
/// have: a network, a Mac, and a Mac that goes away halfway through being asked where it is.
protocol ServiceConnecting: Sendable {

    /// Begins connecting and reports where the Mac turned out to be, or why that cannot be said,
    /// ending as soon as either is known. Nothing follows the first answer.
    func start() -> AsyncStream<EndpointResolution>

    /// Stops it, whether or not it ever answered. Called on every path out of a lookup, so it has to
    /// survive being called twice.
    func cancel()
}

// MARK: -

/// Where a Mac turned out to be, or why that could not be learned.
///
/// Both halves travel in one type because a connection produces exactly one of them and then stops:
/// modelled as a value plus an error, every caller would have to decide what an answer with neither
/// meant.
enum EndpointResolution: Equatable, Sendable {
    case reached(ServerAddress)
    case lost(ServerAddressResolutionFailure)
}
