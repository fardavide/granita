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

    public init() {}

    public func discover() -> AsyncStream<DiscoveryState> {
        AsyncStream { continuation in
            let session = DiscoverySession(
                makeBrowser: { BonjourBrowser() },
                wait: { try await Task.sleep(for: $0) }
            )
            continuation.yield(.searching)
            let running = Task { await session.run(reporting: continuation) }
            continuation.onTermination = { _ in running.cancel() }
        }
    }
}
