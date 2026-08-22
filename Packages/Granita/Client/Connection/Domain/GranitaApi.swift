import CoreApiDomain
import CoreDiffDomain

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

    /// Renames or pins, and answers with the worktree as it now stands.
    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree

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
}
