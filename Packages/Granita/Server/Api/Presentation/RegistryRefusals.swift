import Foundation

import CoreApiDomain
import ServerGitDomain
import ServerWorktreesDomain

/// The sentences a refusal from this Mac travels with over HTTP.
///
/// **The reader stopped carrying these when it moved to `Domain`**, because the window that reads
/// this Mac directly imports the same cases and has no wire to put them on. So the wording lives at
/// whichever boundary is doing the refusing, and this is the API's copy — **byte for byte** what the
/// routes answered before the move, because each of these is a contract a phone displays or branches
/// on, and the acceptance suite asserts the *codes* rather than the words.
extension ApiError {

    init(_ refusal: WorktreeReadError) {
        switch refusal {
        case .projectNotVisible:
            self.init(.projectNotVisible, message: "that project is not enabled")
        case .directoryGone:
            self.init(.worktreeGone, message: "that worktree's directory is no longer there")
        case .notFound:
            self.init(.worktreeGone, message: "no enabled project has that worktree")
        case .notDeletable:
            self.init(
                .worktreeNotDeletable,
                message: "that is the project's own checkout rather than one of its worktrees"
            )
        case .fileNotInChanges:
            self.init(.fileGone, message: "that file is not in this worktree's changes")
        case .notAPicture:
            self.init(.badRequest, message: "that file is not a picture this Mac can serve")
        case .staleContentHash:
            self.init(.staleContentHash, message: "that file has changed since you read it")
        case .tooManyFiles(let limit):
            self.init(.tooLarge, message: "at most \(limit) files at a time")
        case .pictureTooLarge:
            self.init(.tooLarge, message: "that picture is larger than this Mac serves in one piece")
        case .fileUnreadable(let reason):
            self.init(.fileGone, message: "that file could not be read: \(reason)")
        case .notSaved(let reason):
            self.init(.badRequest, message: "could not save that: \(reason)")
        case .git(let failure):
            self = GranitaRouter.gitFailure(failure)
        case .gitUnknown(let description):
            self.init(.gitFailure, message: description)
        case .cancelled:
            // Before the reader existed a cancelled task group escaped the handler untyped and
            // Hummingbird answered an empty 500 — the one response that tells a reader three rooms
            // away precisely nothing. A typed one is strictly better, and the request is being torn
            // down either way.
            self.init(.gitFailure, message: "this Mac stopped reading before it finished")
        }
    }
}
