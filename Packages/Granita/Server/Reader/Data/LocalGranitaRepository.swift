import Foundation

import ClientConnectionDomain
import CoreApiDomain
import CoreDiffDomain
import CoreReviewDomain
import ServerGitDomain
import ServerWorktreesDomain

/// This Mac's own worktrees, reached without a socket.
///
/// **The whole point of merging the two Mac apps.** The window binds the same `GranitaRepository`
/// the phone binds, so every screen above it is unchanged — but on the machine holding the
/// worktrees it binds to `WorktreeReader` rather than to HTTP, and pairing, TLS pinning, Bonjour and
/// the camera leave the path entirely. There is no token to hold, no certificate to verify and no
/// Mac to find.
///
/// It is deliberately thin. Everything it could have reimplemented — folding the viewed marks into
/// the git call, the four-at-a-time diff fan-out, a rename's committed side, refusing a mark against
/// content nobody read — is in the reader, because two copies of those would drift and the drift
/// would show as one reader disagreeing with another about the same worktree.
public struct LocalGranitaRepository: GranitaRepository {

    private let reader: WorktreeReader
    private let now: @Sendable () -> Date

    public init(reader: WorktreeReader, now: @escaping @Sendable () -> Date = { Date() }) {
        self.reader = reader
        self.now = now
    }

    public func projects() async throws(ApiFailure) -> [Project] {
        await reader.projects()
    }

    public func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] {
        try await answering { try await reader.worktrees(inProject: project) }
    }

    /// **Reading, and nothing before it.** The protocol's default reports `.reading(.unknown)`,
    /// which the loading block spells *"Waiting for your Mac's response"* — and there is no response
    /// to wait for. There is nothing to find and nothing to verify either, so this is the only stage
    /// this source ever reports.
    public func worktrees(
        inProject project: ProjectID?,
        reporting progress: @escaping @Sendable (WorktreeReadStage) async -> Void
    ) async throws(ApiFailure) -> [Worktree] {
        await progress(.reading(.thisMac))
        return try await worktrees(inProject: project)
    }

    public func update(
        _ worktree: WorktreeID,
        with patch: WorktreePatch
    ) async throws(ApiFailure) -> Worktree {
        try await answering { try await reader.update(worktree, with: patch) }
    }

    public func delete(_ worktree: WorktreeID) async throws(ApiFailure) {
        try await answering { try await reader.delete(worktree) }
    }

    public func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        try await answering { try await reader.changes(in: worktree) }
    }

    public func diffs(
        of files: [FileID],
        in worktree: WorktreeID,
        contextLines: Int
    ) async throws(ApiFailure) -> [FileDiff] {
        try await answering {
            try await reader.diffs(of: files, in: worktree, contextLines: contextLines)
        }
    }

    public func lines(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(ApiFailure) -> FileLines {
        try await answering {
            try await reader.lines(of: file, in: worktree, side: side, start: start, count: count)
        }
    }

    public func image(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide
    ) async throws(ApiFailure) -> Data {
        try await answering { try await reader.image(of: file, in: worktree, side: side).bytes }
    }

    public func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure) {
        try await answering {
            try await reader.markViewed(
                viewed,
                file: file,
                contentHash: contentHash,
                in: worktree,
                at: now()
            )
        }
    }

    public func review(in worktree: WorktreeID) async throws(ApiFailure) -> [ReviewComment] {
        try await answering { try await reader.review(in: worktree) }
    }

    public func putReview(
        _ comments: [ReviewComment],
        in worktree: WorktreeID
    ) async throws(ApiFailure) {
        try await answering { try await reader.putReview(comments, in: worktree) }
    }

    /// **Never `routeNotServed`, unlike the HTTP path.** That case exists for a Mac too old to hold
    /// these, and this Mac is the one running the code asking.
    public func reviewSettings() async throws(ApiFailure) -> ReviewSettings {
        await reader.reviewSettings()
    }

    public func updateReviewSettings(
        _ patch: ReviewSettingsPatch
    ) async throws(ApiFailure) -> ReviewSettings {
        try await answering {
            try await reader.updateReviewSettings(
                openingLine: patch.openingLine,
                identifier: patch.identifier
            )
        }
    }

    /// Untyped in and typed out, for the reason the routes' own boundary is.
    ///
    /// A typed parameter infers `any Error` at every call site here, and the exhaustiveness that
    /// matters is in `ApiFailure.init(_ refusal:)`, which the compiler still checks case by case.
    /// Anything that is not a refusal goes through the transport rule, which is what turns a torn
    /// down `.task` into `.cancelled` rather than into a screen blaming this Mac.
    private func answering<Answer>(
        _ read: () async throws -> Answer
    ) async throws(ApiFailure) -> Answer {
        do {
            return try await read()
        } catch let refusal as WorktreeReadError {
            throw ApiFailure(refusal)
        } catch {
            throw ApiFailure.forTransport(error)
        }
    }
}

/// What this Mac's own refusal means to the screen in front of it.
///
/// **The same classification the routes make, arriving at a different vocabulary.** A phone learns
/// these from a code on the wire; here there is no wire, so the mapping is made once in each
/// direction from the same cases — which is the property that stops the two readers disagreeing.
extension ApiFailure {

    init(_ refusal: WorktreeReadError) {
        switch refusal {
        case .projectNotVisible:
            self = .projectNotVisible
        case .directoryGone, .notFound:
            self = .worktreeGone
        case .notDeletable:
            self = .worktreeNotDeletable(
                message: "that is the project's own checkout rather than one of its worktrees"
            )
        case .fileNotInChanges:
            self = .fileGone
        case .notAPicture:
            self = .badRequest(message: "that file is not a picture this Mac can serve")
        case .staleContentHash:
            self = .staleContentHash
        case .tooManyFiles, .pictureTooLarge:
            self = .tooLarge
        case .fileUnreadable:
            self = .fileGone
        case .notSaved(let reason):
            self = .badRequest(message: reason)
        case .git(let failure):
            self = ApiFailure(failure)
        case .gitUnknown(let description):
            self = .gitFailure(message: description)
        case .cancelled:
            self = .cancelled
        }
    }

    /// Mirrors the HTTP mapping case for case, including the one that is not a git failure at all:
    /// a working directory that cannot be read is a worktree that has gone, and a screen saying
    /// "git failed" for it would send the reader looking for a broken toolchain.
    init(_ failure: GitError) {
        switch failure {
        case .gitUnavailable(let reason):
            self = .gitFailure(message: "git could not be run: \(reason)")
        case .workingDirectoryUnreadable:
            self = .worktreeGone
        case .commandFailed(_, let exitCode, let standardError):
            // git's own words, verbatim. Nothing else makes this readable.
            self = .gitFailure(message: "git exited \(exitCode): \(standardError)")
        case .terminatedBySignal(_, let signal, let standardError):
            self = .gitFailure(message: "git died on signal \(signal): \(standardError)")
        case .timedOut:
            self = .gitFailure(message: "git took too long and was stopped")
        }
    }
}
