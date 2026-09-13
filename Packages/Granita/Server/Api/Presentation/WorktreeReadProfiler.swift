import CoreDiffDomain
import ServerGitDomain

public actor WorktreeReadProfiler {

    private var measurements: [GitCommandMeasurement] = []
    private let elapsedSince: @Sendable (ContinuousClock.Instant) -> Duration

    public init(
        elapsedSince: @escaping @Sendable (ContinuousClock.Instant) -> Duration = { $0.duration(to: ContinuousClock.now) }
    ) {
        self.elapsedSince = elapsedSince
    }

    public func record(_ measurement: GitCommandMeasurement) {
        measurements.append(measurement)
    }

    public func read(
        enabledProjectCount: Int,
        using reading: @Sendable () async throws(ApiError) -> [Worktree]
    ) async throws(ApiError) -> WorktreeReadProfile {
        let started = ContinuousClock.now
        let worktrees = try await reading()
        return WorktreeReadProfile(
            worktrees: worktrees,
            enabledProjectCount: enabledProjectCount,
            duration: elapsedSince(started),
            gitMeasurements: measurements
        )
    }
}
