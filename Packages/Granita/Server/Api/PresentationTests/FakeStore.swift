import Foundation

import CoreDiffDomain
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
        stored = StoredState(projects: [], worktrees: [:], viewed: [:], devices: devices)
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

    func setViewed(_ isViewed: Bool, file: FileID, contentHash: String) throws(StoreError) {
        try refuseIfAsked()
        var viewed = stored.viewed
        viewed[file] = isViewed ? contentHash : nil
        stored = replacing(viewed: viewed)
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

    private func refuseIfAsked() throws(StoreError) {
        if let failure {
            throw failure
        }
    }

    private func replacing(
        projects: [StoredProject]? = nil,
        worktrees: [WorktreeID: StoredWorktree]? = nil,
        viewed: [FileID: String]? = nil,
        devices: [StoredDevice]? = nil
    ) -> StoredState {
        StoredState(
            projects: projects ?? stored.projects,
            worktrees: worktrees ?? stored.worktrees,
            viewed: viewed ?? stored.viewed,
            devices: devices ?? stored.devices
        )
    }
}
