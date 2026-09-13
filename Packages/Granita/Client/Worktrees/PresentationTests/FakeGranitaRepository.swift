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

    private(set) var cancelledReads = 0

    private var worktrees: [Worktree]
    private let readFailure: ApiFailure?
    private let writeFailure: ApiFailure?
    private let reportingReadStages: [WorktreeReadStage]
    private let reportingAfterReadStages: [WorktreeReadStage]
    private let reportingSecondReadStages: [WorktreeReadStage]?
    private let suspendingReads: Bool
    private let suspendingSecondRead: Bool
    private let suspendedReadNumbers: Set<Int>
    private let ignoringReadCancellation: Bool
    private var suspendedReadContinuations: [Int: AsyncStream<Void>.Continuation] = [:]

    /// Which writes suspend instead of answering, how many have arrived and are suspended, and the
    /// continuations that will let them go.
    ///
    /// **The in-flight state is only observable while a request is outstanding**, and a fake that
    /// answers instantly has no such window at all — so both the row's `Deleting…` and the rename
    /// the phone applies before the Mac replies can only be reasoned about without this, never
    /// asserted.
    private var held: Set<Write> = []
    private var arrived: [Write: Int] = [:]
    private var waiting: [CheckedContinuation<Void, Never>] = []

    /// The two writes a test can hold independently of a suspended list read.
    enum Write: Hashable, Sendable {
        case update
        case deletion
    }

    /// What the first read answers with, when the point of the test is what the **second** one does.
    /// A retry is what a reader presses when a screen has gone wrong, so it is worth holding to its
    /// behaviour on the same model rather than on a second one that was never in the failed state.
    private let refusesTheFirstRead: ApiFailure?
    private let refusesTheSecondRead: ApiFailure?
    private var reads = 0

    init(
        worktrees: [Worktree],
        readFailure: ApiFailure? = nil,
        writeFailure: ApiFailure? = nil,
        refusesTheFirstRead: ApiFailure? = nil,
        refusesTheSecondRead: ApiFailure? = nil,
        reportingReadStages: [WorktreeReadStage] = [],
        reportingAfterReadStages: [WorktreeReadStage] = [],
        reportingSecondReadStages: [WorktreeReadStage]? = nil,
        suspendingReads: Bool = false,
        suspendingSecondRead: Bool = false,
        suspendedReadNumbers: Set<Int> = [],
        ignoringReadCancellation: Bool = false
    ) {
        self.worktrees = worktrees
        self.readFailure = readFailure
        self.writeFailure = writeFailure
        self.refusesTheFirstRead = refusesTheFirstRead
        self.refusesTheSecondRead = refusesTheSecondRead
        self.reportingReadStages = reportingReadStages
        self.reportingAfterReadStages = reportingAfterReadStages
        self.reportingSecondReadStages = reportingSecondReadStages
        self.suspendingReads = suspendingReads
        self.suspendingSecondRead = suspendingSecondRead
        self.suspendedReadNumbers = suspendedReadNumbers
        self.ignoringReadCancellation = ignoringReadCancellation
    }

    func projects() async throws(ApiFailure) -> [Project] {
        []
    }

    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] {
        reads += 1
        let readNumber = reads
        if suspendingReads || (suspendingSecondRead && readNumber == 2) || suspendedReadNumbers.contains(readNumber) {
            let suspended = AsyncStream<Void>.makeStream()
            suspendedReadContinuations[readNumber] = suspended.continuation
            var events = suspended.stream.makeAsyncIterator()
            _ = await events.next()
            suspendedReadContinuations.removeValue(forKey: readNumber)
            if Task.isCancelled {
                cancelledReads += 1
                if !ignoringReadCancellation { throw .cancelled }
            }
        }
        if let readFailure { throw readFailure }
        if let refusesTheFirstRead, readNumber == 1 { throw refusesTheFirstRead }
        if let refusesTheSecondRead, readNumber == 2 { throw refusesTheSecondRead }
        return worktrees
    }

    func worktrees(
        inProject project: ProjectID?,
        reporting progress: @escaping @Sendable (WorktreeReadStage) async -> Void
    ) async throws(ApiFailure) -> [Worktree] {
        let stages = if reads == 1, let reportingSecondReadStages {
            reportingSecondReadStages
        } else {
            reportingReadStages
        }
        for stage in stages {
            await progress(stage)
        }
        let worktrees = try await worktrees(inProject: project)
        for stage in reportingAfterReadStages {
            await progress(stage)
        }
        return worktrees
    }

    func waitUntilReadStarted(count: Int = 1) async {
        while reads < count {
            await Task.yield()
        }
    }

    func releaseHeldRead() {
        for continuation in suspendedReadContinuations.values {
            continuation.finish()
        }
        suspendedReadContinuations.removeAll()
    }

    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree {
        patches.append((worktree: worktree, patch: patch))
        await arrive(.update)
        if let writeFailure { throw writeFailure }
        guard let index = worktrees.firstIndex(where: { $0.id == worktree }) else { throw .worktreeGone }
        worktrees[index] = worktrees[index].answering(patch)
        return worktrees[index]
    }

    func delete(_ worktree: WorktreeID) async throws(ApiFailure) {
        deleted.append(worktree)
        await arrive(.deletion)
        if let writeFailure { throw writeFailure }
        guard worktrees.contains(where: { $0.id == worktree }) else { throw .worktreeGone }
        worktrees.removeAll { $0.id == worktree }
    }

    /// Keeps every write of this kind suspended until a test lets it go.
    func holdTheNext(_ write: Write) {
        held.insert(write)
    }

    /// Suspends until `count` writes of this kind have arrived and are being held.
    func waitForOneToArrive(_ write: Write, count: Int = 1) async {
        while arrived[write, default: 0] < count {
            await Task.yield()
        }
    }

    func releaseHeld(_ write: Write) {
        held.remove(write)
        for continuation in waiting {
            continuation.resume()
        }
        waiting = []
    }

    /// Counts the arrival and suspends if this kind is being held.
    private func arrive(_ write: Write) async {
        arrived[write, default: 0] += 1
        guard held.contains(write) else { return }
        await withCheckedContinuation { continuation in
            waiting.append(continuation)
        }
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

    /// The Mac's own resolution, written out here rather than delegated to `applying(_:)`.
    ///
    /// **`applying(_:)` is now production code — it is what the phone shows while a rename is in
    /// flight — so a fake that called it would be asserting a rule against itself.** The duplication
    /// is what keeps this an independent oracle: the phone's optimistic name and the Mac's answer are
    /// only the same string here because two separate spellings of the rule agree.
    func answering(_ patch: WorktreePatch) -> Worktree {
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
