import Foundation

import CoreDiffDomain

/// Everything the server remembers between runs.
///
/// Small, written rarely, and read on every request. One of the three protocols the architecture
/// permits without a second implementation today: v2's inline comments are the thing that would
/// make this data grow past what one document should hold, and the seam is here so that day is a
/// new conformer rather than a rewrite of every call site.
public protocol Store: Sendable {

    func state() async -> StoredState

    func add(project: StoredProject) async throws(StoreError)
    func setProjectVisible(_ isVisible: Bool, id: ProjectID) async throws(StoreError)

    func setAlias(_ alias: String?, for worktree: WorktreeID) async throws(StoreError)
    func setPinned(_ isPinned: Bool, for worktree: WorktreeID) async throws(StoreError)

    func setViewed(_ isViewed: Bool, file: FileID, contentHash: String) async throws(StoreError)

    func add(device: StoredDevice) async throws(StoreError)
    func removeDevice(id: String) async throws(StoreError)
}

/// A repository the user enabled by hand.
public struct StoredProject: Hashable, Codable, Sendable {

    public let id: ProjectID

    /// The canonical path on this Mac. Held here and never sent anywhere: the identifier is what
    /// travels, and resolving it against this list is what keeps a path from being an input.
    public let path: String

    public let name: String
    public let isVisible: Bool

    public init(id: ProjectID, path: String, name: String, isVisible: Bool) {
        self.id = id
        self.path = path
        self.name = name
        self.isVisible = isVisible
    }
}

/// What a reader decided about one worktree.
public struct StoredWorktree: Hashable, Codable, Sendable {

    public let alias: String?
    public let isPinned: Bool

    public init(alias: String?, isPinned: Bool) {
        self.alias = alias
        self.isPinned = isPinned
    }
}

/// A phone that has paired.
public struct StoredDevice: Hashable, Codable, Sendable {

    public let id: String
    public let name: String
    public let platform: String

    /// The token's hash, never the token. A store that leaks is then a store that leaks nothing
    /// usable, and the only copy of the token itself is in the phone's Keychain.
    public let tokenHash: String

    public let pairedAt: Date

    public init(id: String, name: String, platform: String, tokenHash: String, pairedAt: Date) {
        self.id = id
        self.name = name
        self.platform = platform
        self.tokenHash = tokenHash
        self.pairedAt = pairedAt
    }
}

public struct StoredState: Hashable, Codable, Sendable {

    public let projects: [StoredProject]
    public let worktrees: [WorktreeID: StoredWorktree]

    /// File to the content hash it was marked viewed at, so the mark does not survive an edit.
    public let viewed: [FileID: String]

    public let devices: [StoredDevice]

    /// Whether this state is a blank stand-in for a document that could not be read.
    ///
    /// Not persisted. It exists so a caller can tell "nothing has been set up yet" from "there is
    /// something on disk that this version does not understand", which are the same empty state and
    /// very different situations — writing over the second one loses a reader's whole history.
    public var isFromUnreadableDocument: Bool = false

    public init(
        projects: [StoredProject],
        worktrees: [WorktreeID: StoredWorktree],
        viewed: [FileID: String],
        devices: [StoredDevice]
    ) {
        self.projects = projects
        self.worktrees = worktrees
        self.viewed = viewed
        self.devices = devices
    }

    public static let empty = StoredState(projects: [], worktrees: [:], viewed: [:], devices: [])

    private enum CodingKeys: String, CodingKey {
        case projects
        case worktrees
        case viewed
        case devices
    }
}

public enum StoreError: Error, Hashable, Sendable {

    /// The document could not be written. Carries the reason because the only person who can act on
    /// it is standing at the Mac.
    case notWritable(reason: String)

    /// There is a document on disk that a newer Granita wrote, and overwriting it would drop
    /// whatever this version does not know about.
    case documentIsFromANewerVersion
}
