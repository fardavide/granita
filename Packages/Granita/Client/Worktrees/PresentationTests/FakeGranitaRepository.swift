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

    private var worktrees: [Worktree]
    private let readFailure: ApiFailure?
    private let writeFailure: ApiFailure?

    init(worktrees: [Worktree], readFailure: ApiFailure? = nil, writeFailure: ApiFailure? = nil) {
        self.worktrees = worktrees
        self.readFailure = readFailure
        self.writeFailure = writeFailure
    }

    func projects() async throws(ApiFailure) -> [Project] {
        []
    }

    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] {
        if let readFailure { throw readFailure }
        return worktrees
    }

    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree {
        patches.append((worktree: worktree, patch: patch))
        if let writeFailure { throw writeFailure }
        guard let index = worktrees.firstIndex(where: { $0.id == worktree }) else { throw .worktreeGone }
        worktrees[index] = worktrees[index].applying(patch)
        return worktrees[index]
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
