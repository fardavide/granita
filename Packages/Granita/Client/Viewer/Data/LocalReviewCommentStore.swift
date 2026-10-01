import Synchronization

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain
import CoreReviewDomain

/// This Mac has one durable review: the server document. The synchronous cache bridges the
/// viewer's editing API without writing a second copy to defaults or resurrecting deleted notes.
public final class LocalReviewCommentStore: ReviewCommentStore, Sendable {

    private let repository: any GranitaRepository
    private let cached = Mutex<[WorktreeID: [ReviewComment]]>([:])

    public init(repository: any GranitaRepository) {
        self.repository = repository
    }

    public func comments(in worktree: WorktreeID) -> [ReviewComment] {
        cached.withLock { $0[worktree] ?? [] }
    }

    public func save(_ comments: [ReviewComment], in worktree: WorktreeID) {
        cached.withLock { $0[worktree] = comments }
    }

    public func push(_ comments: [ReviewComment], in worktree: WorktreeID) async -> ReviewSync {
        do {
            try await repository.putReview(comments, in: worktree)
            return .settled
        } catch {
            return .refused(reason: error.diagnostic)
        }
    }

    public func reconcile(in worktree: WorktreeID) async -> [ReviewComment] {
        do {
            let stored = try await repository.review(in: worktree)
            save(stored, in: worktree)
            return stored
        } catch {
            return comments(in: worktree)
        }
    }
}
