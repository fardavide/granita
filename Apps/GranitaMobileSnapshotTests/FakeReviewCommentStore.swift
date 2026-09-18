import ClientViewerDomain
import CoreDiffDomain
import CoreReviewDomain

/// A review that lives in memory, so a baseline photographs the same screen every time it is
/// recorded.
///
/// The bundle's own copy rather than the package's: a test target's doubles are not a product, so
/// nothing here can import the one `ClientViewerPresentationTests` holds.
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

    /// What a push answers with, so a baseline can photograph each caption state without a Mac.
    var pushAnswers: ReviewSync = .settled

    func push(_ comments: [ReviewComment], in worktree: WorktreeID) async -> ReviewSync {
        pushAnswers
    }

    /// No second device in a baseline: the review is whatever the test seeded.
    func reconcile(in worktree: WorktreeID) async -> [ReviewComment] {
        saved
    }
}
