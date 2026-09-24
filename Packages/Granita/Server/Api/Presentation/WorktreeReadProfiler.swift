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

    /// Times a read, whatever the read refuses with.
    ///
    /// **Generic over the thrown type rather than fixed to the API's**, because the thing being
    /// timed is now the registry, which refuses in this Mac's own vocabulary and has no HTTP in it.
    /// A profiler that named one caller's error would make the CLI translate a refusal it only ever
    /// prints.
    public func read<Failure: Error>(
        enabledProjectCount: Int,
        using reading: @Sendable () async throws(Failure) -> [Worktree]
    ) async throws(Failure) -> WorktreeReadProfile {
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
