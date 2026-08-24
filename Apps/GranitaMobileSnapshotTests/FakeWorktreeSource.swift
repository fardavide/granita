import ClientConnectionDomain
import ClientWorktreesDomain
import CoreDiffDomain
import Foundation

/// A Mac and a defaults file, for the screen tests in this bundle.
///
/// Deliberately a second copy of what `Client/Worktrees/PresentationTests` already has, because
/// there is no way to share test code between a SwiftPM test target and an Xcode one and the
/// alternative is a production module existing to be borrowed by tests. Kept as small as the
/// screen needs rather than as capable as the model's own suite needs.
actor FakeGranitaRepository: GranitaRepository {

    private var worktrees: [Worktree]
    private let writeFailure: ApiFailure?

    init(worktrees: [Worktree], writeFailure: ApiFailure? = nil) {
        self.worktrees = worktrees
        self.writeFailure = writeFailure
    }

    func projects() async throws(ApiFailure) -> [Project] { [] }

    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] { worktrees }

    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree {
        if let writeFailure { throw writeFailure }
        guard let found = worktrees.first(where: { $0.id == worktree }) else { throw .worktreeGone }
        return found
    }

    func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges { throw .worktreeGone }

    func diffs(
        of files: [FileID],
        in worktree: WorktreeID,
        contextLines: Int
    ) async throws(ApiFailure) -> [FileDiff] { throw .worktreeGone }

    func lines(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(ApiFailure) -> FileLines { throw .fileGone }

    func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure) { throw .fileGone }
}

// MARK: -

/// In memory, so a snapshot run does not decide how the list opens the next time the app is launched
/// on the simulator it ran on.
final class FakeWorktreeListPreferences: WorktreeListPreferences, @unchecked Sendable {

    private let lock = NSLock()
    private var storedMode: WorktreeListMode
    private var storedShowsQuiet: Bool

    init(mode: WorktreeListMode, showsQuiet: Bool) {
        storedMode = mode
        storedShowsQuiet = showsQuiet
    }

    func mode() -> WorktreeListMode { lock.withLock { storedMode } }

    func remember(_ mode: WorktreeListMode) { lock.withLock { storedMode = mode } }

    func showsQuietWorktrees() -> Bool { lock.withLock { storedShowsQuiet } }

    func rememberShowingQuietWorktrees(_ shows: Bool) { lock.withLock { storedShowsQuiet = shows } }
}

// MARK: -

/// Fixed, so every age in these baselines is the same on every machine that renders them.
nonisolated let aFixedMoment = Date(timeIntervalSince1970: 1_800_000_000)

/// One Mac's worth of worktrees, chosen so that between the listing subjects every row shape
/// design §2 describes is photographed at least once. Shared by the view's suite and the screen's.
nonisolated let aBusyMac: [Worktree] = [
    Worktree(
        id: WorktreeID(rawValue: "w-tls"),
        projectId: ProjectID(rawValue: "granita"),
        projectName: "granita",
        branch: "feat/tls-pinning",
        isPrimary: false,
        isDetached: false,
        isLocked: false,
        hasUnbornHead: false,
        alias: "TLS pinning",
        suggestedAlias: "Add TLS certificate pinning to the pairing handshake",
        displayName: "TLS pinning",
        directoryName: "granita-tls",
        isPinned: true,
        stats: ChangeStats(filesChanged: 12, insertions: 248, deletions: 31),
        lastModified: aFixedMoment.addingTimeInterval(-4 * 60),
        revision: "r1"
    ),

    // A session summary long enough to need both of the two lines the row allows.
    Worktree(
        id: WorktreeID(rawValue: "w-scroll"),
        projectId: ProjectID(rawValue: "granita"),
        projectName: "granita",
        branch: "feat/diff-scroll",
        isPrimary: false,
        isDetached: false,
        isLocked: false,
        hasUnbornHead: false,
        alias: nil,
        suggestedAlias: "Make the diff scroll never reflow above the reader's finger",
        displayName: "Make the diff scroll never reflow above the reader's finger",
        directoryName: "granita-scroll",
        isPinned: false,
        stats: ChangeStats(filesChanged: 34, insertions: 1_204, deletions: 318),
        lastModified: aFixedMoment.addingTimeInterval(-22 * 60),
        revision: "r2"
    ),

    Worktree(
        id: WorktreeID(rawValue: "w-session"),
        projectId: ProjectID(rawValue: "granita"),
        projectName: "granita",
        branch: "feat/session-index",
        isPrimary: false,
        isDetached: false,
        isLocked: false,
        hasUnbornHead: false,
        alias: nil,
        suggestedAlias: nil,
        displayName: "feat/session-index",
        directoryName: "granita-session",
        isPinned: false,
        stats: ChangeStats(filesChanged: 3, insertions: 47, deletions: 6),
        lastModified: aFixedMoment.addingTimeInterval(-2 * 3_600),
        revision: "r3"
    ),

    // No alias, no session, no branch: the one string that can never say what the agent did, and
    // the only row where detachment earns a word.
    Worktree(
        id: WorktreeID(rawValue: "w-bridge"),
        projectId: ProjectID(rawValue: "aura"),
        projectName: "aura",
        branch: nil,
        isPrimary: false,
        isDetached: true,
        isLocked: false,
        hasUnbornHead: false,
        alias: nil,
        suggestedAlias: nil,
        displayName: "bridge-cse_01W9sY8PbT2Du1dFGeYGcwWo",
        directoryName: "bridge-cse_01W9sY8PbT2Du1dFGeYGcwWo",
        isPinned: false,
        stats: ChangeStats(filesChanged: 8, insertions: 96, deletions: 204),
        lastModified: aFixedMoment.addingTimeInterval(-5 * 3_600),
        revision: "r4"
    ),

    // One file, which is a different sentence from twelve.
    Worktree(
        id: WorktreeID(rawValue: "w-coverage"),
        projectId: ProjectID(rawValue: "aura"),
        projectName: "aura",
        branch: "fix/coverage-warning",
        isPrimary: false,
        isDetached: false,
        isLocked: false,
        hasUnbornHead: false,
        alias: nil,
        suggestedAlias: "Fix the coverage script's 3.13 warning",
        displayName: "Fix the coverage script's 3.13 warning",
        directoryName: "aura-coverage",
        isPinned: false,
        stats: ChangeStats(filesChanged: 1, insertions: 2, deletions: 2),
        lastModified: aFixedMoment.addingTimeInterval(-86_400),
        revision: "r5"
    ),

    // The checkout the agent did not work in, hidden by default and the reason the word exists.
    Worktree(
        id: WorktreeID(rawValue: "w-main"),
        projectId: ProjectID(rawValue: "granita"),
        projectName: "granita",
        branch: "main",
        isPrimary: true,
        isDetached: false,
        isLocked: false,
        hasUnbornHead: false,
        alias: nil,
        suggestedAlias: nil,
        displayName: "main",
        directoryName: "granita",
        isPinned: false,
        stats: .zero,
        lastModified: aFixedMoment.addingTimeInterval(-3 * 86_400),
        revision: "r6"
    ),

    // Everything compares against the empty tree here, so the figures would be the whole repository
    // and a lie about what changed.
    Worktree(
        id: WorktreeID(rawValue: "w-spike"),
        projectId: ProjectID(rawValue: "aura"),
        projectName: "aura",
        branch: "main",
        isPrimary: true,
        isDetached: false,
        isLocked: false,
        hasUnbornHead: true,
        alias: nil,
        suggestedAlias: nil,
        displayName: "main",
        directoryName: "aura",
        isPinned: false,
        stats: .zero,
        lastModified: aFixedMoment.addingTimeInterval(-2 * 86_400),
        revision: "r7"
    )
]
