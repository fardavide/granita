import ClientConnectionDomain

/// Finds Granita servers by browsing for the Bonjour service the Mac advertises.
///
/// Deliberately not "connect to a stored address". The Mac binds a service endpoint and the system
/// chooses its port, so a stored `host:port` is stale as soon as the Mac restarts — the instance
/// name is the stable identity and the endpoint is resolved fresh each time.
///
/// One call gives one session, and a session outlives the browsers it runs, because a browser does
/// not survive the app being suspended.
public struct BonjourServerDiscovery: ServerDiscovering {

    private let makeBrowser: @Sendable () -> any ServiceBrowsing

    /// What the app builds: a real browser, and the only place that name is written down.
    public init() {
        self.init(makeBrowser: { BonjourBrowser() })
    }

    /// The seam, without a default on it, so a test that means "no browser at all" has to say so.
    ///
    /// It exists because the question this type answers — *does the screen say something before any
    /// browser has reported* — is about ordering rather than about networking, and answering it
    /// against a real `NWBrowser` made the answer depend on how quickly a daemon replied. That was
    /// measured: it moved this file's coverage between runs of identical code, which is a gate
    /// reporting on the machine it ran on.
    init(makeBrowser: @escaping @Sendable () -> any ServiceBrowsing) {
        self.makeBrowser = makeBrowser
    }

    public func discover() -> AsyncStream<DiscoveryState> {
        AsyncStream { continuation in
            let session = DiscoverySession(
                makeBrowser: makeBrowser,
                wait: { try await Task.sleep(for: $0) }
            )
            continuation.yield(.searching)
            let running = Task { await session.run(reporting: continuation) }
            continuation.onTermination = { _ in running.cancel() }
        }
    }
}
