import Foundation

import CoreDiffDomain
import CoreReviewDomain
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
    private static let schemaVersion = 2

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
            devices: current.devices,
            reviews: current.reviews,
            reviewSettings: current.reviewSettings
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
            devices: current.devices,
            reviews: current.reviews,
            reviewSettings: current.reviewSettings
        ))
    }

    public func removeProject(id: ProjectID) throws(StoreError) {
        let current = state()
        // The project's own record and nothing else. A worktree alias or a viewed mark under it is
        // keyed by a path-derived identifier, so re-adding the same folder finds its aliases where
        // it left them — and nothing outside an enabled project is ever served, so keeping them
        // costs no visibility.
        try write(StoredState(
            projects: current.projects.filter { $0.id != id },
            worktrees: current.worktrees,
            viewed: current.viewed,
            devices: current.devices,
            reviews: current.reviews,
            reviewSettings: current.reviewSettings
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
            devices: current.devices,
            reviews: current.reviews,
            reviewSettings: current.reviewSettings
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
            devices: current.devices,
            reviews: current.reviews,
            reviewSettings: current.reviewSettings
        ))
    }

    public func setViewed(
        _ isViewed: Bool,
        file: FileID,
        in worktree: WorktreeID,
        contentHash: String,
        at date: Date
    ) throws(StoreError) {
        let current = state()
        var viewed = current.viewed
        var marks = viewed[worktree] ?? [:]
        // Keyed by the content that was read. Unmarking is removal rather than a false, so the
        // document does not accumulate a row per file anyone ever looked at and changed their mind
        // about.
        marks[file] = isViewed ? ViewedMark(contentHash: contentHash, viewedAt: date) : nil
        // And a worktree whose last mark went leaves no row either, so the prune below has less to
        // do and the document does not keep a key per worktree anyone ever opened.
        viewed[worktree] = marks.isEmpty ? nil : marks
        try write(StoredState(
            projects: current.projects,
            worktrees: current.worktrees,
            viewed: viewed,
            devices: current.devices,
            reviews: current.reviews,
            reviewSettings: current.reviewSettings
        ))
    }

    public func add(device: StoredDevice) throws(StoreError) {
        let current = state()
        try write(StoredState(
            projects: current.projects,
            worktrees: current.worktrees,
            viewed: current.viewed,
            devices: current.devices.filter { $0.id != device.id } + [device],
            reviews: current.reviews,
            reviewSettings: current.reviewSettings
        ))
    }

    public func removeDevice(id: String) throws(StoreError) {
        let current = state()
        try write(StoredState(
            projects: current.projects,
            worktrees: current.worktrees,
            viewed: current.viewed,
            devices: current.devices.filter { $0.id != id },
            reviews: current.reviews,
            reviewSettings: current.reviewSettings
        ))
    }

    public func setReview(_ comments: [ReviewComment], in worktree: WorktreeID) throws(StoreError) {
        let current = state()
        var reviews = current.reviews
        // An empty review is removal rather than an empty array, so clearing one leaves no row
        // behind — the same rule an unmarked file follows, and what keeps the stored-review count
        // on the Mac's own pane true.
        reviews[worktree] = comments.isEmpty ? nil : comments
        try write(StoredState(
            projects: current.projects,
            worktrees: current.worktrees,
            viewed: current.viewed,
            devices: current.devices,
            reviews: reviews,
            reviewSettings: current.reviewSettings
        ))
    }

    public func prune(keeping worktrees: Set<WorktreeID>, markLimit: Int) throws(StoreError) {
        let current = state()

        var viewed = current.viewed.filter { worktrees.contains($0.key) }
        let reviews = current.reviews.filter { worktrees.contains($0.key) }

        // The cap, oldest first and across every worktree rather than per worktree: the limit is on
        // the document, and a reader with one enormous worktree and nine small ones should not lose
        // the small ones' marks to keep a per-worktree share the big one never uses.
        let total = viewed.values.reduce(0) { $0 + $1.count }
        if total > markLimit {
            let ordered = viewed
                .flatMap { worktree, marks in marks.map { (worktree, $0.key, $0.value) } }
                .sorted { $0.2.viewedAt > $1.2.viewedAt }
                .prefix(markLimit)
            viewed = [:]
            for (worktree, file, mark) in ordered {
                viewed[worktree, default: [:]][file] = mark
            }
        }

        guard viewed != current.viewed || reviews.count != current.reviews.count else { return }

        try write(StoredState(
            projects: current.projects,
            worktrees: current.worktrees,
            viewed: viewed,
            devices: current.devices,
            reviews: reviews,
            reviewSettings: current.reviewSettings
        ))
    }

    public func setReviewSettings(_ settings: ReviewSettings) throws(StoreError) {
        let current = state()
        try write(StoredState(
            projects: current.projects,
            worktrees: current.worktrees,
            viewed: current.viewed,
            devices: current.devices,
            reviews: current.reviews,
            reviewSettings: settings
        ))
    }

    public func reset() throws(StoreError) {
        // The one deliberate act allowed to land on bytes this version cannot decode. Nothing is
        // recoverable from them, and Advanced's "Reset all data" is the only repair a reader has for
        // a damaged document — a reset that refused would leave them with no way out of it but a
        // text editor. A document from a *newer* Granita is still refused: that one is readable, and
        // by something the reader may well go back to.
        if state().unreadable == .couldNotBeDecoded {
            loaded = .empty
        }

        // Through `write` like every other mutation, so the reset is atomic and lands on disk
        // rather than only in this actor. A reset that cleared memory and left the document alone
        // would restore everything it claimed to destroy at the next launch, which is the one
        // outcome nobody would think to check for.
        try write(.empty)
    }

    // MARK: - Disk

    /// Nothing on disk is a first run. Anything else on disk that does not become state is damage or
    /// the future, and the two are told apart before either is acted on.
    private func readFromDisk() -> StoredState {
        guard let data = try? Data(contentsOf: fileUrl) else { return .empty }

        // The version is decoded on its own, and first. It is the one field a later release is
        // guaranteed to still spell the way this one does, so reading it cannot be made to fail by a
        // shape that release changed — which is exactly the document this check exists to catch.
        guard let document = try? JSONDecoder().decode(DocumentVersion.self, from: data) else {
            return .unreadable(.couldNotBeDecoded)
        }
        guard document.schemaVersion <= Self.schemaVersion else {
            return .unreadable(.writtenByANewerVersion)
        }
        guard let state = try? JSONDecoder().decode(StoredState.self, from: data) else {
            return .unreadable(.couldNotBeDecoded)
        }
        return state
    }

    private func write(_ state: StoredState) throws(StoreError) {
        // Whichever of the two knows there is something unreadable on disk, since a caller may hand
        // in a fresh state built from one that was never read successfully.
        if let reason = state.unreadable ?? self.state().unreadable {
            switch reason {
            case .writtenByANewerVersion:
                throw .documentIsFromANewerVersion
            case .couldNotBeDecoded:
                throw .notWritable(
                    reason: "the document on disk could not be read, so it was left as it is"
                )
            }
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
    ///
    /// Encode only. Reading goes through `DocumentVersion` and `StoredState` separately, because a
    /// single type that decodes both would make the version unreadable in precisely the case the
    /// version exists to describe: a document whose state this release cannot decode.
    private struct Envelope: Encodable {
        let schemaVersion: Int
        let state: StoredState

        func encode(to encoder: any Encoder) throws {
            try state.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(schemaVersion, forKey: .schemaVersion)
        }

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
        }
    }

    /// The version alone, and nothing that a later release could have reshaped around it.
    private struct DocumentVersion: Decodable {
        let schemaVersion: Int
    }
}
