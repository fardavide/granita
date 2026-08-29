import Foundation

import ClientConnectionDomain
import CoreDiffDomain

/// A Mac that answers the read routes from a list a test hands it, and records what was written.
///
/// The write is what most of this suite is about, so `patches` is tracked rather than inferred:
/// design §2 says renaming writes the alias and never touches git, and the only way to assert that
/// is to look at the body that left the phone.
actor FakeGranitaRepository: GranitaRepository {

    /// Every patch that reached the Mac, in order, beside the worktree it addressed.
    private(set) var patches: [(worktree: WorktreeID, patch: WorktreePatch)] = []

    /// Every worktree this Mac was asked to destroy, in order.
    ///
    /// Tracked rather than inferred from what is left, because *not asking* and *asking and being
    /// refused* leave the list in the same shape — and a confirmation that cancels must do the first.
    private(set) var deleted: [WorktreeID] = []

    private var worktrees: [Worktree]
    private let readFailure: ApiFailure?
    private let writeFailure: ApiFailure?

    /// Whether a deletion suspends instead of answering, and the ones currently suspended.
    private var holdsDeletions = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var arrived = 0

    /// What the first read answers with, when the point of the test is what the **second** one does.
    /// A retry is what a reader presses when a screen has gone wrong, so it is worth holding to its
    /// behaviour on the same model rather than on a second one that was never in the failed state.
    private let refusesTheFirstRead: ApiFailure?
    private var reads = 0

    init(
        worktrees: [Worktree],
        readFailure: ApiFailure? = nil,
        writeFailure: ApiFailure? = nil,
        refusesTheFirstRead: ApiFailure? = nil
    ) {
        self.worktrees = worktrees
        self.readFailure = readFailure
        self.writeFailure = writeFailure
        self.refusesTheFirstRead = refusesTheFirstRead
    }

    func projects() async throws(ApiFailure) -> [Project] {
        []
    }

    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] {
        reads += 1
        if let readFailure { throw readFailure }
        if let refusesTheFirstRead, reads == 1 { throw refusesTheFirstRead }
        return worktrees
    }

    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree {
        patches.append((worktree: worktree, patch: patch))
        if let writeFailure { throw writeFailure }
        guard let index = worktrees.firstIndex(where: { $0.id == worktree }) else { throw .worktreeGone }
        worktrees[index] = worktrees[index].applying(patch)
        return worktrees[index]
    }

    /// Keeps every deletion suspended until a test lets it go.
    ///
    /// **The in-flight state is only observable while a request is outstanding**, and every other
    /// fake here answers instantly — so without a held request the window the row's `Deleting…`
    /// exists for cannot be photographed by an assertion at all, only reasoned about.
    func holdTheNextDeletion() {
        holdsDeletions = true
    }

    /// Suspends until `count` deletions have arrived and are being held.
    func waitForADeletionToArrive(count: Int = 1) async {
        while arrived < count {
            await Task.yield()
        }
    }

    func releaseHeldDeletions() {
        holdsDeletions = false
        for held in waiting {
            held.resume()
        }
        waiting = []
    }

    func delete(_ worktree: WorktreeID) async throws(ApiFailure) {
        deleted.append(worktree)
        arrived += 1
        if holdsDeletions {
            await withCheckedContinuation { continuation in
                waiting.append(continuation)
            }
        }
        if let writeFailure { throw writeFailure }
        guard worktrees.contains(where: { $0.id == worktree }) else { throw .worktreeGone }
        worktrees.removeAll { $0.id == worktree }
    }

    func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        throw .worktreeGone
    }

    func diffs(
        of files: [FileID],
        in worktree: WorktreeID,
        contextLines: Int
    ) async throws(ApiFailure) -> [FileDiff] {
        throw .worktreeGone
    }

    func lines(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(ApiFailure) -> FileLines {
        throw .fileGone
    }

    func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure) {
        throw .fileGone
    }
}

// MARK: -

private nonisolated extension Worktree {

    /// The Mac's own resolution, applied here so the fake answers what a real one would rather than
    /// echoing the patch back. A fake that returned the alias without re-deriving the display name
    /// would let a row that never updates pass.
    func applying(_ patch: WorktreePatch) -> Worktree {
        let alias: String? = switch patch.alias {
        case .unchanged: self.alias
        case .cleared: nil
        case .set(let alias): alias
        }
        return Worktree(
            id: id,
            projectId: projectId,
            projectName: projectName,
            branch: branch,
            isPrimary: isPrimary,
            isDetached: isDetached,
            isLocked: isLocked,
            hasUnbornHead: hasUnbornHead,
            alias: alias,
            suggestedAlias: suggestedAlias,
            displayName: alias ?? suggestedAlias ?? branch ?? directoryName,
            directoryName: directoryName,
            isPinned: patch.isPinned ?? isPinned,
            stats: stats,
            lastModified: lastModified,
            revision: revision
        )
    }
}
