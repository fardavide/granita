import Foundation

import CoreDiffDomain
import CoreReviewDomain
import ServerStoreDomain

actor FakeStore: Store {

    private var continuations: [UUID: AsyncStream<StoredState>.Continuation] = [:]
    private let subscriptions = AsyncStream.makeStream(of: Void.self)
    private let pausedStateReads = AsyncStream.makeStream(of: Void.self)
    private var stateRead: StateRead = .ready
    private var stored: StoredState {
        didSet {
            for continuation in continuations.values { continuation.yield(stored) }
        }
    }

    init(projects: [StoredProject]) {
        stored = StoredState(
            projects: projects,
            worktrees: [:],
            viewed: [:],
            devices: [],
            reviews: [:],
            reviewSettings: .unset
        )
    }

    func state() async -> StoredState {
        if case .requested = stateRead {
            await withCheckedContinuation { continuation in
                stateRead = .paused(continuation)
                pausedStateReads.continuation.yield(())
            }
        }
        return stored
    }

    func pauseNextStateRead() { stateRead = .requested }

    func waitUntilStateReadPaused() async {
        var reads = pausedStateReads.stream.makeAsyncIterator()
        _ = await reads.next()
    }

    func resumeStateRead() {
        guard case .paused(let continuation) = stateRead else { return }
        stateRead = .ready
        continuation.resume()
    }

    func updates() -> AsyncStream<StoredState> {
        let pair = AsyncStream.makeStream(of: StoredState.self)
        let id = UUID()
        continuations[id] = pair.continuation
        pair.continuation.yield(stored)
        pair.continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(id) }
        }
        subscriptions.continuation.yield(())
        return pair.stream
    }

    func nextSubscription() async {
        var iterator = subscriptions.stream.makeAsyncIterator()
        _ = await iterator.next()
    }

    func add(project: StoredProject) {
        stored = replacing(projects: stored.projects.filter { $0.id != project.id } + [project])
    }

    func setProjectVisible(_ isVisible: Bool, id: ProjectID) {
        stored = replacing(projects: stored.projects.map {
            StoredProject(id: $0.id, path: $0.path, name: $0.name, isVisible: $0.id == id ? isVisible : $0.isVisible)
        })
    }

    func removeProject(id: ProjectID) {
        stored = replacing(projects: stored.projects.filter { $0.id != id })
    }

    func setAlias(_ alias: String?, for worktree: WorktreeID) {
        var worktrees = stored.worktrees
        worktrees[worktree] = StoredWorktree(alias: alias, isPinned: worktrees[worktree]?.isPinned ?? false)
        stored = replacing(worktrees: worktrees)
    }

    func setPinned(_ isPinned: Bool, for worktree: WorktreeID) {
        var worktrees = stored.worktrees
        worktrees[worktree] = StoredWorktree(alias: worktrees[worktree]?.alias, isPinned: isPinned)
        stored = replacing(worktrees: worktrees)
    }

    func setViewed(
        _ isViewed: Bool,
        file: FileID,
        in worktree: WorktreeID,
        contentHash: String,
        at date: Date
    ) {
        var viewed = stored.viewed
        var marks = viewed[worktree] ?? [:]
        marks[file] = isViewed ? ViewedMark(contentHash: contentHash, viewedAt: date) : nil
        viewed[worktree] = marks
        stored = replacing(viewed: viewed)
    }

    func prune(keeping worktrees: Set<WorktreeID>, markLimit: Int) {}
    func add(device: StoredDevice) {}
    func removeDevice(id: String) {}
    func reset() { stored = .empty }
    func setReview(_ comments: [ReviewComment], in worktree: WorktreeID) {}
    func setReviewSettings(_ settings: ReviewSettings) {}

    private func remove(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func replacing(
        projects: [StoredProject]? = nil,
        worktrees: [WorktreeID: StoredWorktree]? = nil,
        viewed: [WorktreeID: [FileID: ViewedMark]]? = nil
    ) -> StoredState {
        StoredState(
            projects: projects ?? stored.projects,
            worktrees: worktrees ?? stored.worktrees,
            viewed: viewed ?? stored.viewed,
            devices: stored.devices,
            reviews: stored.reviews,
            reviewSettings: stored.reviewSettings
        )
    }

    private enum StateRead {
        case ready
        case requested
        case paused(CheckedContinuation<Void, Never>)
    }
}
