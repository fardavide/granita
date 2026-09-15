import Foundation

import ServerGitDomain
import ServerWorktreesDomain

/// Reads a working copy off this Mac's disk.
///
/// **The one place in the server that opens a file it was asked about**, and the reason the seam
/// exists at all: everything else goes through git, which resolves paths itself inside a checkout it
/// was handed. Here the path is joined by hand, so the two rules that make that safe are written down
/// beside the join rather than remembered.
public struct LocalWorktreeFiles: WorktreeFileReading {

    public init() {}

    public func bytes(
        of path: RepositoryRelativePath,
        in worktree: RepositoryLocation,
        upTo maximumBytes: Int
    ) async throws(WorktreeFileError) -> Data {
        // **The path came from git's own account of this checkout, never from a request.** A client
        // addresses a file by identifier and the server resolves it against the change set it just
        // built, so nothing a phone typed reaches this line — which is what makes joining a relative
        // path onto a directory a read of a file git already listed rather than a traversal.
        let url = URL(filePath: worktree.path, directoryHint: .isDirectory)
            .appending(path: path.text, directoryHint: .notDirectory)

        // **Sized before it is read, so an enormous file is refused rather than loaded and then
        // refused.** The ceiling exists to keep a phone-sized payload phone-sized; reading twelve
        // megabytes into memory in order to discover it is thirteen would spend exactly what the
        // ceiling is for.
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? nil
        if let size, size > maximumBytes {
            throw .tooLarge
        }

        let read: Data
        do {
            // Mapped rather than copied: these are pictures, and the largest ones this serves are
            // handed straight to a response body without being looked at.
            read = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw .unreadable(reason: error.localizedDescription)
        }

        // **Checked again after the read**, because the size above is absent for anything that will
        // not answer `resourceValues` and stale for a file an agent is still writing — which is the
        // ordinary state of a screenshot being re-recorded while the phone is looking at it.
        guard read.count <= maximumBytes else { throw .tooLarge }
        return read
    }
}
