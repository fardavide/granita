import Foundation

import ServerGitDomain

/// Reads a file's bytes out of a checkout as they stand on disk.
///
/// **The one thing in this product git cannot answer.** Every other side of every comparison is in
/// the object database and comes back from `show`; the working copy is not, and there is no read-only
/// spelling that puts it there — `show :path` reads the index, which for an edited file is the *old*
/// content, and `hash-object -w` would write to a repository this product never writes to. A binary
/// patch would decode, but only through a deflate stream, which is a codec's worth of code to avoid
/// opening a file.
///
/// It exists for pictures. Text never needs it: a diff already carries the working copy's lines, and
/// context expansion reads them back out of one.
public protocol WorktreeFileReading: Sendable {

    /// The file's bytes, refusing rather than truncating past the ceiling.
    ///
    /// **Refusing rather than trimming is the contract**, because the caller's subject is an image: a
    /// prefix of a PNG is not a smaller picture, it is a corrupt one, and a decoder handed one draws
    /// nothing while the card claims it arrived.
    ///
    /// The location is a directory on this Mac and the path is relative to it, both resolved by the
    /// server against its own registry. Nothing a client sent reaches either — that is the security
    /// boundary rather than a convention.
    func bytes(
        of path: RepositoryRelativePath,
        in worktree: RepositoryLocation,
        upTo maximumBytes: Int
    ) async throws(WorktreeFileError) -> Data
}

/// Why a working copy could not be handed over.
public enum WorktreeFileError: Error, Hashable, Sendable {

    /// It is not there, or this process may not open it — an agent deleting a file mid-read is the
    /// ordinary way to reach this rather than the exceptional one.
    case unreadable(reason: String)

    /// Bigger than this Mac serves in one piece.
    ///
    /// **It carries no size, deliberately.** The committed side of the same comparison reaches the
    /// same refusal by having been cut off at the transport's ceiling, where the only number in hand
    /// is the ceiling itself rather than the file's — so a payload here would be exact on one side of
    /// a picture and a lie on the other, printed in the same sentence.
    case tooLarge
}
