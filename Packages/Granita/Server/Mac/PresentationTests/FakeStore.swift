import Foundation

import CoreDiffDomain
import ServerStoreDomain

/// The store, held in memory, for the two questions Advanced asks it.
///
/// A second hand-written fake rather than a shared one: SwiftPM test targets cannot import each
/// other, and the alternative — a fixtures module shipped in the product so both can see it — puts
/// test doubles in the binary a reader installs. The methods this tab never calls are here because
/// the protocol has them, and they are exactly as interesting as that sounds.
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

    func reset() throws(StoreError) {
        if let failure { throw failure }
        resets += 1
        stored = .empty
    }

    // MARK: - The rest of the seam, which this tab does not reach

    func add(project: StoredProject) throws(StoreError) {}
    func setProjectVisible(_ isVisible: Bool, id: ProjectID) throws(StoreError) {}
    func setAlias(_ alias: String?, for worktree: WorktreeID) throws(StoreError) {}
    func setPinned(_ isPinned: Bool, for worktree: WorktreeID) throws(StoreError) {}
    func setViewed(_ isViewed: Bool, file: FileID, contentHash: String) throws(StoreError) {}
    func add(device: StoredDevice) throws(StoreError) {}
    func removeDevice(id: String) throws(StoreError) {}
}
