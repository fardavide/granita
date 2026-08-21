import Foundation

import CoreDiffDomain
import ServerStoreDomain

/// One JSON document, read once and replaced whole.
///
/// An actor rather than a lock because every mutation is read-modify-write over the entire
/// document, and two of those interleaving loses whichever finished first. There is no database
/// here on purpose: the data is small, is written when a person taps something, and stays
/// repairable with a text editor.
public actor JsonDocumentStore: Store {

    /// Bumped when the document's shape changes in a way this version could not read back.
    ///
    /// A document from the future is left alone rather than reinterpreted: reading it with today's
    /// rules and writing it back would silently drop every field a newer Granita added, and the
    /// fields most likely to be added are the ones a reader spent time producing.
    private static let schemaVersion = 1

    private let fileUrl: URL
    private var loaded: StoredState?

    public init(fileUrl: URL) {
        self.fileUrl = fileUrl
    }

    public func state() -> StoredState {
        if let loaded { return loaded }
        let state = readFromDisk()
        loaded = state
        return state
    }

    public func add(project: StoredProject) throws(StoreError) {
        var current = state()
        var projects = current.projects.filter { $0.id != project.id }
        projects.append(project)
        current = StoredState(
            projects: projects,
            worktrees: current.worktrees,
            viewed: current.viewed,
            devices: current.devices
        )
        try write(current)
    }

    public func setProjectVisible(_ isVisible: Bool, id: ProjectID) throws(StoreError) {
        let current = state()
        try write(StoredState(
            projects: current.projects.map {
                $0.id == id
                    ? StoredProject(id: $0.id, path: $0.path, name: $0.name, isVisible: isVisible)
                    : $0
            },
            worktrees: current.worktrees,
            viewed: current.viewed,
            devices: current.devices
        ))
    }

    public func setAlias(_ alias: String?, for worktree: WorktreeID) throws(StoreError) {
        let current = state()
        var worktrees = current.worktrees
        // Read-modify-write of the one record rather than replacement of it, so setting an alias
        // cannot clear a pin the reader set separately.
        worktrees[worktree] = StoredWorktree(
            alias: alias,
            isPinned: worktrees[worktree]?.isPinned ?? false
        )
        try write(StoredState(
            projects: current.projects,
            worktrees: worktrees,
            viewed: current.viewed,
            devices: current.devices
        ))
    }

    public func setPinned(_ isPinned: Bool, for worktree: WorktreeID) throws(StoreError) {
        let current = state()
        var worktrees = current.worktrees
        worktrees[worktree] = StoredWorktree(
            alias: worktrees[worktree]?.alias,
            isPinned: isPinned
        )
        try write(StoredState(
            projects: current.projects,
            worktrees: worktrees,
            viewed: current.viewed,
            devices: current.devices
        ))
    }

    public func setViewed(_ isViewed: Bool, file: FileID, contentHash: String) throws(StoreError) {
        let current = state()
        var viewed = current.viewed
        // Keyed by the content that was read. Unmarking is removal rather than a false, so the
        // document does not accumulate a row per file anyone ever looked at and changed their mind
        // about.
        viewed[file] = isViewed ? contentHash : nil
        try write(StoredState(
            projects: current.projects,
            worktrees: current.worktrees,
            viewed: viewed,
            devices: current.devices
        ))
    }

    public func add(device: StoredDevice) throws(StoreError) {
        let current = state()
        try write(StoredState(
            projects: current.projects,
            worktrees: current.worktrees,
            viewed: current.viewed,
            devices: current.devices.filter { $0.id != device.id } + [device]
        ))
    }

    public func removeDevice(id: String) throws(StoreError) {
        let current = state()
        try write(StoredState(
            projects: current.projects,
            worktrees: current.worktrees,
            viewed: current.viewed,
            devices: current.devices.filter { $0.id != id }
        ))
    }

    // MARK: - Disk

    private func readFromDisk() -> StoredState {
        guard let data = try? Data(contentsOf: fileUrl) else { return .empty }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return .empty }
        guard envelope.schemaVersion <= Self.schemaVersion else {
            var state = StoredState.empty
            state.isFromUnreadableDocument = true
            return state
        }
        return envelope.state
    }

    private func write(_ state: StoredState) throws(StoreError) {
        guard state.isFromUnreadableDocument == false, self.state().isFromUnreadableDocument == false else {
            throw .documentIsFromANewerVersion
        }
        do {
            let encoder = JSONEncoder()
            // Sorted and pretty-printed because this file is meant to be openable: the recovery
            // path for anything that goes wrong here is a person reading it.
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(Envelope(schemaVersion: Self.schemaVersion, state: state))

            try FileManager.default.createDirectory(
                at: fileUrl.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Atomic, so a crash mid-write leaves the previous document rather than half of a new
            // one. Foundation writes to a neighbouring temporary file and renames it, and the
            // rename is what makes the swap indivisible.
            try data.write(to: fileUrl, options: .atomic)
            loaded = state
        } catch {
            throw .notWritable(reason: "\(error)")
        }
    }

    /// The document, which is the state plus the version that wrote it.
    private struct Envelope: Codable {
        let schemaVersion: Int
        let state: StoredState

        init(schemaVersion: Int, state: StoredState) {
            self.schemaVersion = schemaVersion
            self.state = state
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            state = try StoredState(from: decoder)
        }

        func encode(to encoder: any Encoder) throws {
            try state.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(schemaVersion, forKey: .schemaVersion)
        }

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
        }
    }
}
