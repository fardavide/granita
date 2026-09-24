import Testing

import CoreApiDomain
import ServerGitDomain
import ServerWorktreesDomain

@testable import ServerApiPresentation

/// The wire's half of the reader's refusals.
///
/// **Asserted as a mapping rather than through the routes, because the mapping *is* the contract.**
/// Each of these puts a different screen in front of a reader, and contriving a real HTTP failure
/// per case would test the plumbing rather than the translation — the same argument
/// `GitFailureMappingTests` makes for git's own errors.
///
/// **And these assert the words, which the acceptance suite does not.** It checks codes and one
/// message; a refusal reworded by accident would have passed it. The reader carries causes now, so
/// this file is the only thing holding the sentences a phone displays.
@Suite("Registry refusals")
struct RegistryRefusalsTests {

    @Test(arguments: [
        (
            WorktreeReadError.projectNotVisible,
            ApiErrorCode.projectNotVisible,
            "that project is not enabled"
        ),
        (
            WorktreeReadError.directoryGone,
            ApiErrorCode.worktreeGone,
            "that worktree's directory is no longer there"
        ),
        (
            WorktreeReadError.notFound,
            ApiErrorCode.worktreeGone,
            "no enabled project has that worktree"
        ),
        (
            WorktreeReadError.notDeletable,
            ApiErrorCode.worktreeNotDeletable,
            "that is the project's own checkout rather than one of its worktrees"
        ),
        (
            WorktreeReadError.fileNotInChanges,
            ApiErrorCode.fileGone,
            "that file is not in this worktree's changes"
        ),
        (
            WorktreeReadError.notAPicture,
            ApiErrorCode.badRequest,
            "that file is not a picture this Mac can serve"
        ),
        (
            WorktreeReadError.staleContentHash,
            ApiErrorCode.staleContentHash,
            "that file has changed since you read it"
        ),
        (
            WorktreeReadError.tooManyFiles(limit: 20),
            ApiErrorCode.tooLarge,
            "at most 20 files at a time"
        ),
        (
            WorktreeReadError.pictureTooLarge,
            ApiErrorCode.tooLarge,
            "that picture is larger than this Mac serves in one piece"
        ),
        (
            WorktreeReadError.fileUnreadable(reason: "permission denied"),
            ApiErrorCode.fileGone,
            "that file could not be read: permission denied"
        ),
        (
            WorktreeReadError.notSaved(reason: "the disk is full"),
            ApiErrorCode.badRequest,
            "could not save that: the disk is full"
        ),
        (
            WorktreeReadError.gitUnknown(description: "something else threw"),
            ApiErrorCode.gitFailure,
            "something else threw"
        ),
        (
            WorktreeReadError.cancelled,
            ApiErrorCode.gitFailure,
            "this Mac stopped reading before it finished"
        )
    ])
    func `given this Mac refuses when it is put on the wire then it keeps the code and the sentence it shipped with`(
        refusal: WorktreeReadError,
        code: ApiErrorCode,
        message: String
    ) {
        // given - when
        let error = ApiError(refusal)

        // then
        #expect(error.error.code == code)
        #expect(error.error.message == message)
    }

    @Test
    func `given git refuses when it is put on the wire then it travels as git's own failure`() {
        // given
        let refusal = WorktreeReadError.git(.timedOut(command: .worktreeStatus))

        // when
        let error = ApiError(refusal)

        // then — routed through the git mapping rather than reworded here, so the two stay one
        // answer rather than two that happen to agree today.
        #expect(error.error.code == .gitFailure)
        #expect(error.error.message == "git took too long and was stopped")
    }
}
