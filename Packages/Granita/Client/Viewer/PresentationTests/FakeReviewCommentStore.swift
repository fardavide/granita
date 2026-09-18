import ClientViewerDomain
import CoreDiffDomain
import CoreReviewDomain

/// A review that lives in memory, so a test can seed one and read back what the model wrote.
///
/// A class rather than a struct because the point of it is what the model saved, and the model holds
/// its store by value the way it holds everything else.
// Only ever touched from the main actor: the model that calls it is main-actor isolated and every
// test in this bundle is a `@MainActor` suite. That is the invariant the compiler cannot see.
final class FakeReviewCommentStore: ReviewCommentStore, @unchecked Sendable {

    private(set) var saved: [ReviewComment]

    /// Every push the model made, so a test can assert that saving and offering are separate acts.
    private(set) var pushed: [[ReviewComment]] = []

    /// What the Mac is pretending to hold, which `reconcile` unions into what this phone wrote.
    var onTheMac: [ReviewComment] = []

    /// What a push answers with, so the caption's states can be driven without a network.
    var pushAnswers: ReviewSync = .settled

    init(holding comments: [ReviewComment] = []) {
        saved = comments
    }

    func comments(in worktree: WorktreeID) -> [ReviewComment] {
        saved
    }

    func save(_ comments: [ReviewComment], in worktree: WorktreeID) {
        saved = comments
    }

    func push(_ comments: [ReviewComment], in worktree: WorktreeID) async -> ReviewSync {
        pushed.append(comments)
        return pushAnswers
    }

    func reconcile(in worktree: WorktreeID) async -> [ReviewComment] {
        let anchors = Set(saved.map(\.anchor))
        saved += onTheMac.filter { anchors.contains($0.anchor) == false }
        return saved
    }
}
