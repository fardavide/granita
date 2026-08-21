/// Why a question to git has no answer.
///
/// Every case carries enough to be read on a phone, three rooms away from the Mac that produced it.
/// That is the whole design brief for this type: the reader cannot open a terminal, cannot re-run
/// the command, and cannot see what git said unless it is carried here.
public enum GitError: Error, Hashable, Sendable {

    /// git could not be run, or could not be run to completion.
    ///
    /// The reason is the operating system's rather than git's — nothing got far enough to write a
    /// line of standard error to quote.
    case gitUnavailable(reason: String)

    /// The checkout is not where it was.
    ///
    /// Its own case because it is the ordinary end of a worktree an agent removed while the phone
    /// was reading it, and the caller drops the worktree rather than showing anyone an error.
    case workingDirectoryUnreadable(location: RepositoryLocation, reason: String)

    /// git ran and refused, with everything it wrote to standard error.
    case commandFailed(command: GitCommand, exitCode: Int32, standardError: String)

    /// git died on a signal rather than exiting, which is not something it does on its own.
    case terminatedBySignal(command: GitCommand, signal: Int32, standardError: String)

    /// git was still running when its time ran out and was torn down.
    case timedOut(command: GitCommand)
}
