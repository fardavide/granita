import Foundation
import Synchronization

import ClientConnectionDomain
import CoreDiffDomain
import CoreReviewDomain

final class FakeMacReaderRepository: GranitaRepository {
    let worktrees: [Worktree]
    let fileDiffs: [FileDiff]
    let holdsWorktreeRead: Bool
    let changesFailure: ApiFailure?
    let diffFailure: ApiFailure?
    private let clock = Mutex(Date(timeIntervalSince1970: 1_800_000_000))
    private let changesReadsSuspended = Mutex(false)

    init(
        worktrees: [Worktree],
        fileDiffs: [FileDiff],
        holdsWorktreeRead: Bool,
        changesFailure: ApiFailure? = nil,
        diffFailure: ApiFailure? = nil
    ) {
        self.worktrees = worktrees
        self.fileDiffs = fileDiffs
        self.holdsWorktreeRead = holdsWorktreeRead
        self.changesFailure = changesFailure
        self.diffFailure = diffFailure
    }

    var now: Date { clock.withLock { $0 } }

    func suspendChangesReads() {
        changesReadsSuspended.withLock { $0 = true }
    }

    func projects() async throws(ApiFailure) -> [Project] { [] }

    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] {
        worktrees
    }

    func worktrees(
        inProject project: ProjectID?,
        reporting progress: @escaping @Sendable (WorktreeReadStage) async -> Void
    ) async throws(ApiFailure) -> [Worktree] {
        if holdsWorktreeRead {
            clock.withLock { $0 = $0.addingTimeInterval(47) }
        }
        await progress(.reading(.thisMac))
        if holdsWorktreeRead {
            do {
                try await Task.sleep(for: .seconds(3_600))
            } catch {
                throw .cancelled
            }
        }
        return worktrees
    }

    func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        if let changesFailure { throw changesFailure }
        if changesReadsSuspended.withLock({ $0 }) {
            // Suspend without keeping the cooperative pool runnable; cancellation ends the fixture.
            do {
                try await Task.sleep(for: .seconds(3_600))
            } catch {
                throw .cancelled
            }
        }
        return WorktreeChanges(
            revision: "reader-snapshot",
            stats: ChangeStats(filesChanged: fileDiffs.count, insertions: fileDiffs.count, deletions: fileDiffs.count),
            files: fileDiffs.map(\.file),
            isTruncated: false
        )
    }

    func diffs(of files: [FileID], in worktree: WorktreeID, contextLines: Int) async throws(ApiFailure) -> [FileDiff] {
        if let diffFailure { throw diffFailure }
        return fileDiffs.filter { files.contains($0.file.id) }
    }

    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree {
        guard let found = worktrees.first(where: { $0.id == worktree }) else { throw .worktreeGone }
        return found
    }

    func delete(_ worktree: WorktreeID) async throws(ApiFailure) { throw .worktreeGone }

    func lines(of file: FileID, in worktree: WorktreeID, side: DiffSide, start: Int, count: Int) async throws(ApiFailure) -> FileLines {
        throw .fileGone
    }

    func image(of file: FileID, in worktree: WorktreeID, side: DiffSide) async throws(ApiFailure) -> Data { throw .fileGone }

    func markViewed(_ viewed: Bool, file: FileID, contentHash: String, in worktree: WorktreeID) async throws(ApiFailure) {}

    func review(in worktree: WorktreeID) async throws(ApiFailure) -> [ReviewComment] { [] }
    func putReview(_ comments: [ReviewComment], in worktree: WorktreeID) async throws(ApiFailure) {}
    func reviewSettings() async throws(ApiFailure) -> ReviewSettings { .unset }
    func updateReviewSettings(_ patch: ReviewSettingsPatch) async throws(ApiFailure) -> ReviewSettings { .unset }
}
