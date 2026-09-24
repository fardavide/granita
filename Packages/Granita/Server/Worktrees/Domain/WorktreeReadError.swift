import Foundation

import ServerGitDomain

/// Why this Mac could not answer, in its own vocabulary rather than in either caller's.
///
/// **It carries causes and never sentences.** Two things read this Mac now — the HTTP routes a phone
/// reaches and the window reading the disk it is running from — and each spells a refusal for its own
/// reader: the routes put a code and a message on the wire, the window puts a screen in front of
/// somebody. A message chosen here would be one of those two wordings leaking into the other.
///
/// The one exception is where the sentence *is* the cause: git's standard error, the reason a file
/// could not be opened, the reason a write was refused. Those are carried verbatim because inventing
/// them here would be worse than passing them on, and both boundaries print them the same way.
public enum WorktreeReadError: Error, Sendable {

    /// The identifier names a project that exists and has not been enabled.
    case projectNotVisible

    /// Resolved to a directory that is no longer on disk.
    case directoryGone

    /// No enabled project holds that worktree at all.
    case notFound

    /// The worktree is there and must not be removed: it is the project's own checkout.
    case notDeletable

    /// The file is not among this worktree's changes.
    case fileNotInChanges

    /// The path does not claim a picture this Mac can serve.
    case notAPicture

    /// The file changed since the reader saw it, so the mark would be over a version nobody read.
    case staleContentHash

    /// More files in one batch than this Mac answers at a time.
    case tooManyFiles(limit: Int)

    /// Bigger than this Mac serves in one piece.
    case pictureTooLarge

    /// The working copy could not be opened, carrying the system's reason.
    case fileUnreadable(reason: String)

    /// This Mac's own document refused the write, carrying its reason.
    case notSaved(reason: String)

    /// git refused, carrying its own error so a boundary can classify it.
    ///
    /// **Classified at the boundary rather than here**, because which of these becomes "the worktree
    /// is gone" and which becomes "git failed" is a contract with whoever is reading — and the HTTP
    /// mapping is tested as a mapping precisely because each branch puts a different screen up.
    case git(GitError)

    /// Something threw that was not a `GitError`, which is a bug rather than a condition.
    case gitUnknown(description: String)

    /// The caller called the read off, so nothing failed.
    ///
    /// **A case rather than a `gitUnknown`**, because the diff fan-out runs a task group and a
    /// cancelled group throws `CancellationError` from inside it. Folded in with the unknowns it
    /// would reach a screen as *git failed*, on a window the reader closed themselves — the same
    /// defect `ApiFailure.cancelled` exists to prevent on the phone.
    case cancelled
}
