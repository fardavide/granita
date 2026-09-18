import Foundation

import ClientConnectionDomain
import CoreApiDomain
import CoreDiffDomain
import CoreReviewDomain

/// A Mac that answers the review's four routes and records what was sent to it.
///
/// Only the review half is real. Everything else refuses, because a test in this bundle that started
/// asking for a diff should fail loudly rather than pass against an invented answer.
final class FakeReviewRepository: GranitaRepository, @unchecked Sendable {

    /// What this Mac holds, which a test seeds to stand for a second device's half of a review.
    var stored: [ReviewComment]

    /// What the review routes refuse with, when they refuse.
    var failure: ApiFailure?

    private(set) var received: [[ReviewComment]] = []

    init(holding stored: [ReviewComment] = [], failing failure: ApiFailure? = nil) {
        self.stored = stored
        self.failure = failure
    }

    func review(in worktree: WorktreeID) async throws(ApiFailure) -> [ReviewComment] {
        if let failure { throw failure }
        return stored
    }

    func putReview(_ comments: [ReviewComment], in worktree: WorktreeID) async throws(ApiFailure) {
        if let failure { throw failure }
        received.append(comments)
        stored = comments
    }

    func reviewSettings() async throws(ApiFailure) -> ReviewSettings {
        if let failure { throw failure }
        return .unset
    }

    func updateReviewSettings(
        _ patch: ReviewSettingsPatch
    ) async throws(ApiFailure) -> ReviewSettings {
        if let failure { throw failure }
        return .unset
    }

    // MARK: - The rest of the seam, which no review test reaches

    func projects() async throws(ApiFailure) -> [Project] { throw .worktreeGone }
    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] {
        throw .worktreeGone
    }
    func worktrees(
        inProject project: ProjectID?,
        reporting progress: @escaping @Sendable (WorktreeReadStage) async -> Void
    ) async throws(ApiFailure) -> [Worktree] { throw .worktreeGone }
    func update(
        _ worktree: WorktreeID,
        with patch: WorktreePatch
    ) async throws(ApiFailure) -> Worktree { throw .worktreeGone }
    func delete(_ worktree: WorktreeID) async throws(ApiFailure) { throw .worktreeGone }
    func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        throw .worktreeGone
    }
    func diffs(
        of files: [FileID],
        in worktree: WorktreeID,
        contextLines: Int
    ) async throws(ApiFailure) -> [FileDiff] { throw .worktreeGone }
    func lines(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(ApiFailure) -> FileLines { throw .fileGone }
    func image(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide
    ) async throws(ApiFailure) -> Data { throw .fileGone }
    func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure) { throw .fileGone }
}
