import ClientViewerDomain
import CoreDiffDomain

/// A review that lives in memory, so a test can seed one and read back what the model wrote.
///
/// A class rather than a struct because the point of it is what the model saved, and the model holds
/// its store by value the way it holds everything else.
// Only ever touched from the main actor: the model that calls it is main-actor isolated and every
// test in this bundle is a `@MainActor` suite. That is the invariant the compiler cannot see.
final class FakeReviewCommentStore: ReviewCommentStore, @unchecked Sendable {

    private(set) var saved: [ReviewComment]

    init(holding comments: [ReviewComment] = []) {
        saved = comments
    }

    func comments(in worktree: WorktreeID) -> [ReviewComment] {
        saved
    }

    func save(_ comments: [ReviewComment], in worktree: WorktreeID) {
        saved = comments
    }
}
