import ClientConnectionDomain

/// Keeps a browser running for as long as anyone is listening.
///
/// A dead browser is dead for good — the documented remedy is to create another one — and one dies
/// every time iOS suspends the app. A session that stopped at the first death left the screen frozen
/// on whatever that death looked like until the app was force-quit, which is exactly what a reopened
/// Granita showed. This replaces the browser instead, and only calls it a refusal once the
/// replacements keep dying too.
struct DiscoverySession {

    private let makeBrowser: @Sendable () -> any ServiceBrowsing
    private let wait: @Sendable (Duration) async throws -> Void

    init(
        makeBrowser: @escaping @Sendable () -> any ServiceBrowsing,
        wait: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.makeBrowser = makeBrowser
        self.wait = wait
    }

    /// Reports what discovery knows until the surrounding task is cancelled.
    func run(reporting continuation: AsyncStream<DiscoveryState>.Continuation) async {
        var policy = BrowserRestartPolicy()
        while !Task.isCancelled {
            let browser = makeBrowser()
            var restart: BrowserRestart?
            for await event in browser.start() {
                switch event {
                case .ready:
                    policy.recordReady()
                    continuation.yield(.searching)
                case .waiting(let error):
                    continuation.yield(BrowserRestartPolicy.stateWhileWaiting(on: error))
                case .failed(let error):
                    restart = policy.restart(after: error)
                case .found(let servers):
                    continuation.yield(.found(servers))
                }
            }
            browser.cancel()
            // A browser that stopped without dying was cancelled, and the only thing that cancels
            // one is this session going away.
            guard let restart else { break }
            if let report = restart.report {
                continuation.yield(report)
            }
            do {
                try await wait(restart.delay)
            } catch {
                break
            }
        }
        continuation.finish()
    }
}
