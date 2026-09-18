import Foundation

import CoreDiffDomain
import CoreReviewDomain
import ServerStoreDomain

/// The store, held in memory.
///
/// The real one writes a document and is asserted where that matters; here what is wanted is a
/// place devices go so that pairing can be watched without a temporary directory per test.
actor FakeStore: Store {

    /// What to throw instead of writing, for the tests that are about a store which refuses —
    /// a full disk, or a document a newer Granita wrote.
    private let failure: StoreError?

    private var stored: StoredState

    init(devices: [StoredDevice] = [], failure: StoreError? = nil) {
        stored = StoredState(
            projects: [],
            worktrees: [:],
            viewed: [:],
            devices: devices,
            reviews: [:],
            reviewSettings: .unset
        )
        self.failure = failure
    }

    func state() -> StoredState {
        stored
    }

    func add(project: StoredProject) throws(StoreError) {
        try refuseIfAsked()
        stored = replacing(projects: stored.projects.filter { $0.id != project.id } + [project])
    }

    func setProjectVisible(_ isVisible: Bool, id: ProjectID) throws(StoreError) {
        try refuseIfAsked()
        stored = replacing(projects: stored.projects.map {
            guard $0.id == id else { return $0 }
            return StoredProject(id: $0.id, path: $0.path, name: $0.name, isVisible: isVisible)
        })
    }

    func removeProject(id: ProjectID) throws(StoreError) {
        try refuseIfAsked()
        stored = replacing(projects: stored.projects.filter { $0.id != id })
    }

    func setAlias(_ alias: String?, for worktree: WorktreeID) throws(StoreError) {
        try refuseIfAsked()
        var worktrees = stored.worktrees
        worktrees[worktree] = StoredWorktree(alias: alias, isPinned: worktrees[worktree]?.isPinned ?? false)
        stored = replacing(worktrees: worktrees)
    }

    func setPinned(_ isPinned: Bool, for worktree: WorktreeID) throws(StoreError) {
        try refuseIfAsked()
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
    ) throws(StoreError) {
        try refuseIfAsked()
        var viewed = stored.viewed
        var marks = viewed[worktree] ?? [:]
        marks[file] = isViewed ? ViewedMark(contentHash: contentHash, viewedAt: date) : nil
        viewed[worktree] = marks.isEmpty ? nil : marks
        stored = replacing(viewed: viewed)
    }

    func prune(keeping worktrees: Set<WorktreeID>, markLimit: Int) throws(StoreError) {
        try refuseIfAsked()
        stored = replacing(
            viewed: stored.viewed.filter { worktrees.contains($0.key) },
            reviews: stored.reviews.filter { worktrees.contains($0.key) }
        )
    }

    func add(device: StoredDevice) throws(StoreError) {
        try refuseIfAsked()
        stored = replacing(devices: stored.devices + [device])
    }

    func removeDevice(id: String) throws(StoreError) {
        try refuseIfAsked()
        stored = replacing(devices: stored.devices.filter { $0.id != id })
    }

    func reset() throws(StoreError) {
        try refuseIfAsked()
        stored = .empty
    }

    func setReview(_ comments: [ReviewComment], in worktree: WorktreeID) throws(StoreError) {
        try refuseIfAsked()
        var reviews = stored.reviews
        reviews[worktree] = comments.isEmpty ? nil : comments
        stored = replacing(reviews: reviews)
    }

    func setReviewSettings(_ settings: ReviewSettings) throws(StoreError) {
        try refuseIfAsked()
        stored = replacing(reviewSettings: settings)
    }

    private func refuseIfAsked() throws(StoreError) {
        if let failure {
            throw failure
        }
    }

    private func replacing(
        projects: [StoredProject]? = nil,
        worktrees: [WorktreeID: StoredWorktree]? = nil,
        viewed: [WorktreeID: [FileID: ViewedMark]]? = nil,
        devices: [StoredDevice]? = nil,
        reviews: [WorktreeID: [ReviewComment]]? = nil,
        reviewSettings: ReviewSettings? = nil
    ) -> StoredState {
        StoredState(
            projects: projects ?? stored.projects,
            worktrees: worktrees ?? stored.worktrees,
            viewed: viewed ?? stored.viewed,
            devices: devices ?? stored.devices,
            reviews: reviews ?? stored.reviews,
            reviewSettings: reviewSettings ?? stored.reviewSettings
        )
    }
}
