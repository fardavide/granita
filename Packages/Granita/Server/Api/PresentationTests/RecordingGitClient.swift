import Foundation

import ServerGitDomain

/// The real git client with a note of every checkout it was run in.
///
/// **A decorator rather than a fake**, because what these tests are about is what a route asks git
/// for, and answering it with anything other than git would change the question. It exists for the
/// one thing no assertion on a response body can see: how much of this Mac a request read before it
/// answered. `PATCH /v1/worktrees/:id` writes one line to a JSON document and used to rebuild a
/// change set for every worktree of every enabled project to describe the result — correct, and
/// minutes long on a real machine.
actor RecordingGitClient: GitClient {

    /// Every command git was given, in order, beside the directory it was run in.
    private(set) var runs: [(command: GitCommand, location: RepositoryLocation)] = []

    /// Which checkouts a change set was built for.
    ///
    /// **`worktreeStatus` is the marker, and it is exact rather than indicative**: `changeSet(in:)`
    /// runs it once and nothing else in the service runs it more than once per call, so one entry
    /// here is one change set. That is the expensive thing — six invocations plus a hash of every
    /// changed file, measured at 122.7 seconds across ten real repositories — and counting it is how
    /// a route that reads more of this Mac than it needs to is caught.
    var checkoutsAChangeSetWasBuiltFor: [RepositoryLocation] {
        runs.filter { $0.command == .worktreeStatus }.map(\.location)
    }

    private let underlying: any GitClient

    init(_ underlying: any GitClient) {
        self.underlying = underlying
    }

    /// Forgets what has been recorded so far, so a test can set the Mac up and then measure one
    /// request rather than everything that led to it.
    func forget() {
        runs = []
    }

    func run(_ command: GitCommand, in location: RepositoryLocation) async throws(GitError) -> GitOutput {
        runs.append((command: command, location: location))
        return try await underlying.run(command, in: location)
    }
}
