public struct GitCommandMeasurement: Hashable, Sendable {

    public enum Outcome: Hashable, Sendable {
        case succeeded
        case failed
    }

    public let command: GitCommand
    public let duration: Duration
    public let outcome: Outcome

    public init(command: GitCommand, duration: Duration, outcome: Outcome) {
        self.command = command
        self.duration = duration
        self.outcome = outcome
    }
}

public struct MeasuredGitClient: GitClient {

    private let client: any GitClient
    private let reporting: @Sendable (GitCommandMeasurement) async -> Void
    private let elapsedSince: @Sendable (ContinuousClock.Instant) -> Duration

    public init(
        client: any GitClient,
        reporting: @escaping @Sendable (GitCommandMeasurement) async -> Void,
        elapsedSince: @escaping @Sendable (ContinuousClock.Instant) -> Duration = { $0.duration(to: ContinuousClock.now) }
    ) {
        self.client = client
        self.reporting = reporting
        self.elapsedSince = elapsedSince
    }

    public func run(_ command: GitCommand, in location: RepositoryLocation) async throws(GitError) -> GitOutput {
        let started = ContinuousClock.now
        do {
            let output = try await client.run(command, in: location)
            await reporting(GitCommandMeasurement(command: command, duration: elapsedSince(started), outcome: .succeeded))
            return output
        } catch {
            await reporting(GitCommandMeasurement(command: command, duration: elapsedSince(started), outcome: .failed))
            throw error
        }
    }
}
