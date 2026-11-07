import Foundation

public protocol WorktreeObservationTiming: Sendable {
    func now() async -> Duration
    func sleep(for duration: Duration) async throws(CancellationError)
}

public struct ContinuousWorktreeObservationTiming: WorktreeObservationTiming {
    private let clock: ContinuousClock
    private let started: ContinuousClock.Instant

    public init() {
        let clock = ContinuousClock()
        self.clock = clock
        started = clock.now
    }

    public func now() async -> Duration { started.duration(to: clock.now) }

    public func sleep(for duration: Duration) async throws(CancellationError) {
        do { try await clock.sleep(for: duration) }
        catch { throw CancellationError() }
    }
}
