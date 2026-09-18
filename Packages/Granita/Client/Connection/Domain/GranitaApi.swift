import Foundation

import CoreApiDomain
import CoreDiffDomain
import CorePairingDomain
import CoreReviewDomain

/// The two routes a phone may reach before it has a token.
///
/// Separate from the repository below because the separation is the security boundary rather than a
/// tidy-up: everything on the repository requires a bearer token, everything here is unauthenticated
/// and therefore rate limited, and a route that moved from one to the other would be a hole nobody
/// reviewed.
public protocol ServerPairing: Sendable {

    /// What this Mac calls itself and which contract it serves.
    ///
    /// Asked **before** offering to pair, because a code spent against a Mac whose contract this
    /// phone cannot read is a code wasted for a reason the reader cannot see.
    func health() async throws(ApiFailure) -> HealthResponse

    /// Spends a one-time code and returns the only copy of the token it bought.
    func pair(with code: String, as device: PairingDevice) async throws(ApiFailure) -> PairedDevice

    /// The key this Mac presented, once anything has spoken to it.
    ///
    /// **Read back rather than assumed, and that is the point of it existing.** On the scanned path
    /// it is the pin the link carried and this only confirms it. On the spoken path there was no pin
    /// to check against, so this is the whole of what got trusted — and a caller that constructed a
    /// fingerprint instead of asking would pin a Mac it never handshook with.
    ///
    /// `nil` before first contact. After a code has been spent a handshake has happened by
    /// definition, so a `nil` there is a transport that cannot say what it trusted, which is not a
    /// pairing anyone should be told succeeded.
    func trustedFingerprint() async -> SpkiFingerprint?
}

/// Everything the phone reads from a Mac it has paired with.
///
/// One of the three abstractions SPEC §3 permits ahead of a second implementation, and the reason
/// is on the record: it is what lets the app run against a bundled dataset with no Mac present,
/// without the views knowing. Everywhere else a protocol earns its place by having a fake behind it
/// today.
///
/// Every address here is an opaque identifier the Mac resolves against its own registry. **No
/// method takes a filesystem path**, which is the single most important rule in this API: the
/// payload is private source code and a path parameter is a traversal hole.
public protocol GranitaRepository: Sendable {

    func projects() async throws(ApiFailure) -> [Project]

    /// Every worktree, or only one project's.
    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree]

    func worktrees(
        inProject project: ProjectID?,
        reporting progress: @escaping @Sendable (WorktreeReadStage) async -> Void
    ) async throws(ApiFailure) -> [Worktree]

    /// Renames or pins, and answers with the worktree as it now stands.
    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree

    /// Asks the Mac to take a checkout off it, with whatever uncommitted work is in it.
    ///
    /// **The one call here that destroys something, and the only one with nothing to undo it.** The
    /// Mac forces the removal, because every worktree this app lists has uncommitted work in it and
    /// the unforced form would refuse on nearly all of them — so the confirmation in front of this
    /// is not ceremony, it is the whole safeguard. The branch survives; the directory does not.
    ///
    /// It answers with nothing. The row is gone, and what the list holds afterwards is this side's
    /// business rather than a worktree the Mac would have to invent to return.
    func delete(_ worktree: WorktreeID) async throws(ApiFailure)

    /// The stats and the file list, from one comparison. Never hunks.
    func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges

    /// Several files' diffs in one request, because opening a forty-file worktree must not be
    /// forty-one round trips each spawning a git process.
    func diffs(
        of files: [FileID],
        in worktree: WorktreeID,
        contextLines: Int
    ) async throws(ApiFailure) -> [FileDiff]

    /// Raw lines for context expansion, which is state the client owns: a stateless parameter
    /// cannot express "hunk 2 expanded up and hunk 5 expanded down".
    func lines(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(ApiFailure) -> FileLines

    /// One side of a changed picture, as the bytes the Mac holds.
    ///
    /// **Bytes rather than a decoded image**, because decoding is a framework's job and this is the
    /// layer that draws the line between what arrived and what can be drawn: a `.png` holding
    /// something else is one card saying so rather than a repository inventing a failure.
    ///
    /// Which sides exist is `ImageSides`, decided from the file's status on both ends — so a caller
    /// never asks for the committed side of a file that has just arrived.
    func image(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide
    ) async throws(ApiFailure) -> Data

    /// Marks a file read, against the content that was read.
    ///
    /// The hash is not decoration: a mark applied to a version nobody saw is the one way this
    /// feature can actively mislead someone, so the Mac refuses it rather than applying it.
    func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure)

    /// The review this Mac holds for a worktree, which may be more than this phone wrote.
    ///
    /// A second device reviewing the same worktree is the case: both sets are the review, and the
    /// union of them in document order is what a reader wants.
    func review(in worktree: WorktreeID) async throws(ApiFailure) -> [ReviewComment]

    /// Replaces the review this Mac holds, which is also how it is cleared.
    func putReview(
        _ comments: [ReviewComment],
        in worktree: WorktreeID
    ) async throws(ApiFailure)

    /// The two settings that shape every exported review.
    ///
    /// **A Mac that predates these answers 404 rather than refusing the client**, which is a
    /// deliberate departure from §8's rule that a route 426s on a newer client: refusing would cost
    /// the reader every screen that already worked in order to protect two settings. The phone reads
    /// that as "this Mac cannot store them" and keeps using its own.
    func reviewSettings() async throws(ApiFailure) -> ReviewSettings

    /// Changes only the settings named, using the presence-versus-null idiom the worktree patch
    /// already uses — so a queued edit cannot overwrite a field this phone never read.
    func updateReviewSettings(
        _ patch: ReviewSettingsPatch
    ) async throws(ApiFailure) -> ReviewSettings
}

/// What a reader changed about the review's shape, and nothing they did not.
///
/// **Absent means "leave it alone", which is why both fields are doubly optional where the value
/// itself is optional.** A queued opening line written while the Mac was away must not carry a label
/// style this phone never read, and an opening line the reader cleared is a real value rather than
/// an absence — `.some(nil)` clears it, `nil` leaves it.
public struct ReviewSettingsPatch: Hashable, Sendable {

    public let openingLine: String??
    public let identifier: ReviewIdentifier?

    public init(openingLine: String??, identifier: ReviewIdentifier?) {
        self.openingLine = openingLine
        self.identifier = identifier
    }
}

extension GranitaRepository {

    public func worktrees(
        inProject project: ProjectID?,
        reporting progress: @escaping @Sendable (WorktreeReadStage) async -> Void
    ) async throws(ApiFailure) -> [Worktree] {
        await progress(.reading(.unknown))
        return try await worktrees(inProject: project)
    }
}
