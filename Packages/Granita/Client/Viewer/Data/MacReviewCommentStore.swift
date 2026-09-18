import Foundation

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain
import CoreReviewDomain

/// The review, on the Mac, with this phone keeping a copy that never waits for it.
///
/// **It wraps the local store rather than replacing it.** Davide's call of 17 September 2026: the
/// Mac is the source of truth and the phone keeps a local copy and reconciles. That is two different
/// answers to two different moments — the Mac wins at *read* time, when a fresh device asks what a
/// worktree's review is, and the phone wins at *write* time, because the alternative is discarding
/// something a reader typed on a screen that accepted it.
///
/// **So every write lands locally first and synchronously.** A closed laptop is the normal condition
/// here, not an error, and iOS ends a backgrounded app whenever it likes; a review that needed the
/// network to be saved would lose an afternoon to a dropped connection. The push is what the Mac
/// gets, and it is allowed to fail.
public struct MacReviewCommentStore: ReviewCommentStore {

    private let local: ReviewCommentStore
    private let repository: GranitaRepository

    public init(local: ReviewCommentStore, repository: GranitaRepository) {
        self.local = local
        self.repository = repository
    }

    /// This phone's copy, always, and without suspending.
    ///
    /// The Mac's version arrives through `reconcile`, which the screen calls when it opens. Reading
    /// through the network here would put an `await` in front of drawing a diff and a spinner in
    /// front of a review that is already on this device.
    public func comments(in worktree: WorktreeID) -> [ReviewComment] {
        local.comments(in: worktree)
    }

    public func save(_ comments: [ReviewComment], in worktree: WorktreeID) {
        local.save(comments, in: worktree)
    }

    public func push(_ comments: [ReviewComment], in worktree: WorktreeID) async -> ReviewSync {
        do {
            try await repository.putReview(comments, in: worktree)
            return .settled
        } catch {
            // Absent routes are a Mac that predates reviews rather than one that refused: there is
            // nothing to queue for and nothing wrong, so the reader is told their review is this
            // phone's rather than shown a failure they cannot act on.
            if case .routeNotServed = error {
                return .notStorable
            }
            // Everything else is a Mac that could have taken it and did not, which is worth a
            // sentence — the reader's next move is the copy button, and that still works.
            return comments.isEmpty
                ? .refused(reason: error.diagnostic)
                : .pending(count: comments.count, of: comments.count)
        }
    }

    public func reconcile(in worktree: WorktreeID) async -> [ReviewComment] {
        let mine = local.comments(in: worktree)
        guard let theirs = try? await repository.review(in: worktree) else { return mine }

        // The union, keyed by anchor, because the anchor is a comment's identity: a second tap on a
        // commented row is an edit rather than a duplicate, and the same rule settles which of two
        // devices' comments on one run survives.
        var merged = mine
        let anchors = Set(mine.map(\.anchor))
        merged.append(contentsOf: theirs.filter { anchors.contains($0.anchor) == false })

        // Kept locally so the union survives the app being ended before the next reconcile, and so
        // the count under the copy button is a count of what is actually in the document.
        local.save(merged, in: worktree)
        return merged
    }
}
