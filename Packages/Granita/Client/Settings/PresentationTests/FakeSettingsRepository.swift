import Foundation

import ClientConnectionDomain
import CoreApiDomain
import CoreDiffDomain
import CoreReviewDomain

/// A Mac that answers the two settings routes and records what it was sent.
///
/// Everything else refuses: a test here that started asking for a diff should fail loudly rather
/// than pass against an answer nobody meant to give it.
final class FakeSettingsRepository: GranitaRepository, @unchecked Sendable {

    var stored: ReviewSettings
    var failure: ApiFailure?

    /// Every patch that reached this Mac, which is how a test asserts that only the field the reader
    /// touched travelled.
    private(set) var patches: [ReviewSettingsPatch] = []

    init(holding stored: ReviewSettings = .unset, failing failure: ApiFailure? = nil) {
        self.stored = stored
        self.failure = failure
    }

    func reviewSettings() async throws(ApiFailure) -> ReviewSettings {
        if let failure { throw failure }
        return stored
    }

    func updateReviewSettings(
        _ patch: ReviewSettingsPatch
    ) async throws(ApiFailure) -> ReviewSettings {
        patches.append(patch)
        if let failure { throw failure }
        stored = ReviewSettings(
            openingLine: patch.openingLine ?? stored.openingLine,
            identifier: patch.identifier ?? stored.identifier
        )
        return stored
    }

    // MARK: - The rest of the seam, which this screen never reaches

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
    func review(in worktree: WorktreeID) async throws(ApiFailure) -> [ReviewComment] { [] }
    func putReview(_ comments: [ReviewComment], in worktree: WorktreeID) async throws(ApiFailure) {}
}
