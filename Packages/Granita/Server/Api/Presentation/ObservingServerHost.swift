import ServerApiDomain
import ServerWorktreesDomain

public struct ObservingServerHost: ServerHosting {
    private let host: any ServerHosting
    private let observation: any WorktreeObserving
    private let wakes: any WakeNotifications
    private let preparing: @Sendable () async -> Void

    public init(
        host: any ServerHosting,
        observation: any WorktreeObserving,
        wakes: any WakeNotifications,
        preparing: @escaping @Sendable () async -> Void
    ) {
        self.host = host
        self.observation = observation
        self.wakes = wakes
        self.preparing = preparing
    }

    public func run() -> AsyncStream<ServerRunState> {
        let host = host
        let observation = observation
        let wakes = wakes
        let preparing = preparing
        return AsyncStream { continuation in
            let serving = Task {
                let preparation = Task { await preparing() }
                await ObservingServerLifetime(observation: observation, wakes: wakes).run {
                    for await state in host.run() { continuation.yield(state) }
                    preparation.cancel()
                }
                await preparation.value
                continuation.finish()
            }
            continuation.onTermination = { _ in serving.cancel() }
        }
    }
}
