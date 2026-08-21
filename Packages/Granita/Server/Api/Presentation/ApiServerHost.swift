import ServerApiDomain

/// Runs the API server and says what it is doing, which is what the menu bar item draws.
///
/// The states are a stream rather than a property because binding is not instant and can fail: the
/// interesting moments are the transitions, and a status item that only ever showed the last one
/// would say "starting" until someone opened the menu.
public struct ApiServerHost: ServerHosting {

    private let configuration: ApiServerConfiguration

    public init(configuration: ApiServerConfiguration) {
        self.configuration = configuration
    }

    public func run() -> AsyncStream<ServerRunState> {
        let configuration = configuration
        return AsyncStream { continuation in
            let serving = Task {
                continuation.yield(.starting)
                do {
                    try await ApiServer.make(configuration: configuration) { endpoint in
                        if let endpoint {
                            continuation.yield(.running(endpoint))
                        } else {
                            // Not a failure to serve — a failure to say where. Reported rather
                            // than guessed at, because a status line naming a port nothing is
                            // listening on is worse than one saying it does not know.
                            continuation.yield(.failed(reason: "the server is up but did not report a port"))
                        }
                    }
                    .runService()
                    continuation.yield(.stopped)
                } catch {
                    continuation.yield(.failed(reason: "\(error)"))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in serving.cancel() }
        }
    }
}
