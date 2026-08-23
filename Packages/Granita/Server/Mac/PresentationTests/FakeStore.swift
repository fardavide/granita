import Foundation

import CoreDiffDomain
import ServerStoreDomain

/// The store, held in memory, for the questions the Settings window asks it.
///
/// A second hand-written fake rather than a shared one: SwiftPM test targets cannot import each
/// other, and the alternative — a fixtures module shipped in the product so both can see it — puts
/// test doubles in the binary a reader installs.
///
/// The project and device mutations are real rather than empty, because those two tabs are the ones
/// that **write** through this seam, and each writes the thing it exists for: whether what a reader
/// switched on is what is served, and whether a phone they revoked can still read it.
actor FakeStore: Store {

    private(set) var resets = 0

    private let failure: StoreError?
    private var stored: StoredState

    init(
        projects: [StoredProject] = [],
        devices: [StoredDevice] = [],
        failure: StoreError? = nil
    ) {
        stored = StoredState(projects: projects, worktrees: [:], viewed: [:], devices: devices)
        self.failure = failure
    }

    func state() -> StoredState {
        stored
    }

    func add(project: StoredProject) throws(StoreError) {
        if let failure { throw failure }
        stored = replacing(projects: stored.projects.filter { $0.id != project.id } + [project])
    }

    func setProjectVisible(_ isVisible: Bool, id: ProjectID) throws(StoreError) {
        if let failure { throw failure }
        stored = replacing(projects: stored.projects.map {
            guard $0.id == id else { return $0 }
            return StoredProject(id: $0.id, path: $0.path, name: $0.name, isVisible: isVisible)
        })
    }

    func removeProject(id: ProjectID) throws(StoreError) {
        if let failure { throw failure }
        stored = replacing(projects: stored.projects.filter { $0.id != id })
    }

    func removeDevice(id: String) throws(StoreError) {
        if let failure { throw failure }
        stored = replacing(devices: stored.devices.filter { $0.id != id })
    }

    func reset() throws(StoreError) {
        if let failure { throw failure }
        resets += 1
        stored = .empty
    }

    // MARK: - The rest of the seam, which the Settings window does not reach

    func setAlias(_ alias: String?, for worktree: WorktreeID) throws(StoreError) {}
    func setPinned(_ isPinned: Bool, for worktree: WorktreeID) throws(StoreError) {}
    func setViewed(_ isViewed: Bool, file: FileID, contentHash: String) throws(StoreError) {}
    func add(device: StoredDevice) throws(StoreError) {}

    // MARK: -

    private func replacing(
        projects: [StoredProject]? = nil,
        devices: [StoredDevice]? = nil
    ) -> StoredState {
        StoredState(
            projects: projects ?? stored.projects,
            worktrees: stored.worktrees,
            viewed: stored.viewed,
            devices: devices ?? stored.devices
        )
    }
}
