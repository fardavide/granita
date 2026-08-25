import ClientConnectionDomain

/// Finds where a browsed Mac is by dialling its Bonjour service and reading the address it landed
/// on.
///
/// The lookup is bounded and the connection is stopped on every path out, which are the two things
/// a screen leans on: a Mac that has gone away must end as a sentence rather than as a spinner
/// nobody can leave, and a connection nobody is listening to is a socket and an mDNS query held open
/// for as long as the app lives.
public struct BonjourServerAddressResolver: ServerAddressResolving {

    private let makeConnection: @Sendable (DiscoveredServer) -> any ServiceConnecting

    /// How long a Mac has to say where it is.
    ///
    /// It was listed by a browse seconds ago, so on a working network the answer is immediate and
    /// five seconds is never reached. What it bounds is the other case — a Mac that slept between
    /// the browse and the tap — where the connection would otherwise keep hoping and the reader
    /// would keep waiting with six words typed and nothing to press.
    private let patience: Duration

    /// What the app builds: a real connection, and the only place that name is written down.
    public init() {
        self.init(makeConnection: { BonjourServiceConnection(to: $0) }, patience: .seconds(5))
    }

    /// The seam, without defaults on it, so a test that means "this Mac never answers" has to say
    /// both halves of that out loud.
    init(
        makeConnection: @escaping @Sendable (DiscoveredServer) -> any ServiceConnecting,
        patience: Duration
    ) {
        self.makeConnection = makeConnection
        self.patience = patience
    }

    public func address(
        of server: DiscoveredServer
    ) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        let connection = makeConnection(server)
        // Both ways out of the lines below have to stop it, including the one where it answered
        // perfectly and nothing looks like it went wrong.
        defer { connection.cancel() }
        switch await firstAnswer(from: connection) {
        case .reached(let address): return address
        case .lost(let failure): throw failure
        }
    }

    /// Whatever the connection says, or the patience running out — expressed as the second one
    /// **cancelling** the first rather than as a race between two results.
    ///
    /// That is what leaves one ending instead of two: a stream that stops without having answered is
    /// the timeout in every case that reaches production, because the only thing that ends this
    /// connection early is this app deciding to.
    private func firstAnswer(from connection: any ServiceConnecting) async -> EndpointResolution {
        let givingUp = Task {
            try await Task.sleep(for: patience)
            connection.cancel()
        }
        defer { givingUp.cancel() }

        for await resolution in connection.start() {
            return resolution
        }
        return .lost(.unreachable(diagnostic: "the Mac did not say where it was before the connection ended"))
    }
}
