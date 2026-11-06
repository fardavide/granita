import ServerGitDomain

public enum WorktreeObservationError: Error, Hashable, Sendable {
    case couldNotCreateStream
    case couldNotStartStream
    case git(GitError)
    case invalidGitDirectory(RepositoryLocation)
}

public protocol WorktreeObservationSource: Sendable {
    func events(
        watching locations: [RepositoryLocation]
    ) async throws(WorktreeObservationError) -> AsyncStream<WorktreeObservationEvent>

    func stop() async
}
