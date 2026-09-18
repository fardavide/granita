import Foundation

import CoreDiffDomain
import CoreReviewDomain

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

    /// Forgets a project entirely, which is not the same as switching it off.
    ///
    /// Design §4 keeps the two verbs apart at both ends. A project switched off is one this Mac
    /// still remembers being asked about and can be switched back on; a removed one is a path this
    /// Mac has no further business holding. It is also how `Locate…` moves a project, because an
    /// identifier is a hash of a path and a folder that moved is a different project to everything
    /// that resolves one.
    func removeProject(id: ProjectID) async throws(StoreError)

    func setAlias(_ alias: String?, for worktree: WorktreeID) async throws(StoreError)
    func setPinned(_ isPinned: Bool, for worktree: WorktreeID) async throws(StoreError)

    /// Marks or unmarks one file in one worktree.
    ///
    /// The worktree is carried because a file identifier is a hash of a repository-relative path, so
    /// the same file in two checkouts of one project is the same identifier. Without it a mark set in
    /// one worktree applies in the other, and no mark can be dropped when its worktree is deleted.
    func setViewed(
        _ isViewed: Bool,
        file: FileID,
        in worktree: WorktreeID,
        contentHash: String,
        at date: Date
    ) async throws(StoreError)

    /// Drops what belongs to worktrees that are gone, and caps what is left.
    ///
    /// `SPEC.md` §9's startup rule, for both collections that grow without a reader ever deciding to
    /// grow them. Marks are capped oldest-first; reviews are not capped at all, because a review is
    /// something a reader wrote and losing the oldest one silently is worse than a large document.
    func prune(keeping worktrees: Set<WorktreeID>, markLimit: Int) async throws(StoreError)

    func add(device: StoredDevice) async throws(StoreError)
    func removeDevice(id: String) async throws(StoreError)

    /// Replaces one worktree's review whole, which is also how it is cleared.
    ///
    /// The whole set rather than one comment at a time, for the reason the phone's own store already
    /// takes it that way: a review is small, whoever is calling holds all of it, and a per-comment
    /// interface makes clearing a loop with a half-cleared review in the middle of it.
    func setReview(_ comments: [ReviewComment], in worktree: WorktreeID) async throws(StoreError)

    func setReviewSettings(_ settings: ReviewSettings) async throws(StoreError)

    /// Forgets everything: every project, every device, every alias, every pin, every mark.
    ///
    /// Advanced's one-way door, and it is all four records rather than a choice of them. A reset
    /// that left one behind would leave the reader believing the rest went too, and the record most
    /// likely to be left is the one that matters — a project still enabled is a repository still
    /// being served.
    func reset() async throws(StoreError)
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

    /// What each worktree's reader has marked viewed, and what it was that they read.
    ///
    /// **Keyed by worktree first, which is what `SPEC.md` §9 asked for and 0.14.2 did not do.** Until
    /// now this was one flat map from a file's path hash to a content hash, and a file identifier is
    /// derived from a repository-relative path alone — so two worktrees of one project shared every
    /// mark, and neither could be pruned when its worktree went away because nothing recorded which
    /// worktree a mark belonged to.
    public let viewed: [WorktreeID: [FileID: ViewedMark]]

    public let devices: [StoredDevice]

    /// The review a reader has written about each worktree, whole.
    ///
    /// **Keyed per worktree**, because that is what a review is of: two agents in two checkouts of
    /// one project are two reviews, and one key for both would hand each reader the other's notes.
    /// **The second unbounded collection in this document, and the worse one** — a comment carries an
    /// excerpt, so a review is kilobytes where a viewed mark is bytes, and the worktrees they belong
    /// to are made and destroyed by an agent rather than by a reader.
    public let reviews: [WorktreeID: [ReviewComment]]

    /// What every exported review looks like, wherever it is exported from.
    ///
    /// One object rather than one per worktree or per device: it is a fact about how this reader
    /// writes, and Davide asked for it to be the same on the phone and the Mac.
    public let reviewSettings: ReviewSettings

    /// Why this state is a blank stand-in rather than a first run, when it is one.
    ///
    /// Not persisted. It exists so a caller can tell "nothing has been set up yet" from "there is
    /// something on disk that this version does not understand", which are the same empty state and
    /// very different situations — writing over the second one loses a reader's whole history. The
    /// two reasons stay apart because they reach a reader as different sentences: one names a
    /// Granita to upgrade, the other a file to repair.
    public var unreadable: UnreadableDocument?

    public init(
        projects: [StoredProject],
        worktrees: [WorktreeID: StoredWorktree],
        viewed: [WorktreeID: [FileID: ViewedMark]],
        devices: [StoredDevice],
        reviews: [WorktreeID: [ReviewComment]],
        reviewSettings: ReviewSettings
    ) {
        self.projects = projects
        self.worktrees = worktrees
        self.viewed = viewed
        self.devices = devices
        self.reviews = reviews
        self.reviewSettings = reviewSettings
    }

    /// The old decoder, kept as `SPEC.md` §9 instructs rather than replaced.
    ///
    /// A document written before reviews existed carries neither key, and the two fields are not
    /// optional in the type because an absent review is an empty review and an unset setting is a
    /// real answer. So they are decoded if present and defaulted if not, which is the whole of the
    /// migration: a version 1 document opens as a version 2 one with no review written yet, and the
    /// first write puts it in the new shape.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projects = try container.decode([StoredProject].self, forKey: .projects)
        worktrees = try container.decode([WorktreeID: StoredWorktree].self, forKey: .worktrees)
        if let marks = try? container.decode([WorktreeID: [FileID: ViewedMark]].self, forKey: .viewed) {
            viewed = marks
        } else {
            // Version 1's marks were a flat map from file to content hash with no worktree on them,
            // and they cannot be migrated: a file identifier is a hash of a repository-relative path,
            // so there is no worktree to assign one to. Guessing costs a reader a file they have not
            // seen drawn as read, which is the one failure this feature must not have — so they are
            // decoded, discarded, and re-made by a reader in one pass.
            //
            // Decoded rather than ignored so that a `viewed` key which is neither shape still makes
            // the document unreadable, instead of quietly emptying a collection this version would
            // then write back.
            _ = try container.decode([FileID: String].self, forKey: .viewed)
            viewed = [:]
        }
        devices = try container.decode([StoredDevice].self, forKey: .devices)
        reviews = try container.decodeIfPresent(
            [WorktreeID: [ReviewComment]].self,
            forKey: .reviews
        ) ?? [:]
        reviewSettings = try container.decodeIfPresent(
            ReviewSettings.self,
            forKey: .reviewSettings
        ) ?? .unset
    }

    public static let empty = StoredState(
        projects: [],
        worktrees: [:],
        viewed: [:],
        devices: [],
        reviews: [:],
        reviewSettings: .unset
    )

    /// A blank state that remembers there is something on disk it could not read.
    public static func unreadable(_ reason: UnreadableDocument) -> StoredState {
        var state = StoredState.empty
        state.unreadable = reason
        return state
    }

    private enum CodingKeys: String, CodingKey {
        case projects
        case worktrees
        case viewed
        case devices
        case reviews
        case reviewSettings
    }
}

/// One file a reader has marked viewed, and the two facts that let the mark expire.
public struct ViewedMark: Hashable, Codable, Sendable {

    /// The content that was read. A mark keyed by content rather than by path is what makes it
    /// self-correcting: the agent changes the file, the hash moves, and the mark stops applying
    /// without anybody clearing it. That behaviour is the point of the feature.
    public let contentHash: String

    /// When it was marked, which is the only thing that can order marks for the cap.
    ///
    /// `SPEC.md` §9 caps this collection at twenty thousand entries by dropping the oldest, and
    /// "oldest" is inexpressible without a date — which is why the cap did not exist before this
    /// field did. It is never shown to a reader: the bar says "viewed", not "viewed 4 minutes ago".
    public let viewedAt: Date

    public init(contentHash: String, viewedAt: Date) {
        self.contentHash = contentHash
        self.viewedAt = viewedAt
    }
}

/// Why a document on disk could not be turned into state.
public enum UnreadableDocument: Hashable, Sendable {

    /// It names a schema this version does not have. Reading it with today's rules would drop every
    /// field a newer Granita added, and those are the fields a reader spent time producing.
    case writtenByANewerVersion

    /// The bytes are not this document at all. Nothing is recoverable from them here, so they are
    /// left exactly as they are for a person with a text editor.
    case couldNotBeDecoded
}

public enum StoreError: Error, Hashable, Sendable {

    /// The document could not be written. Carries the reason because the only person who can act on
    /// it is standing at the Mac.
    case notWritable(reason: String)

    /// There is a document on disk that a newer Granita wrote, and overwriting it would drop
    /// whatever this version does not know about.
    case documentIsFromANewerVersion
}
