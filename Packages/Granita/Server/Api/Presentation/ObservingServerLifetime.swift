import ServerApiDomain
import ServerWorktreesDomain

public struct ObservingServerLifetime: Sendable {
    private let observation: any WorktreeObserving
    private let wakes: any WakeNotifications

    public init(observation: any WorktreeObserving, wakes: any WakeNotifications) {
        self.observation = observation
        self.wakes = wakes
    }

    public func run<Failure: Error>(
        _ serving: @Sendable () async throws(Failure) -> Void
    ) async throws(Failure) {
        let observing = Task { await observation.run() }
        let events = wakes.wakes()
        let waking = Task {
            for await _ in events {
                guard Task.isCancelled == false else { return }
                await observation.reconcile()
            }
        }
        let result: Result<Void, Failure>
        do throws(Failure) {
            try await serving()
            result = .success(())
        } catch {
            result = .failure(error)
        }
        waking.cancel()
        observing.cancel()
        await observation.stop()
        await waking.value
        await observing.value
        try result.get()
    }
}
