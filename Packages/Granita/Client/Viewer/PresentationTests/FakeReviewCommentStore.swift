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

    private(set) var invocations: [Invocation] = []

    /// What the Mac is pretending to hold, which `reconcile` unions into what this phone wrote.
    var onTheMac: [ReviewComment] = []

    /// What a push answers with, so the caption's states can be driven without a network.
    var pushAnswers: ReviewSync = .settled

    /// Whether a push waits to be let go, so a test can make a second change while the first is
    /// still on its way to the Mac — which is the only moment their order can go wrong.
    var holdsPushes = false

    var holdsReconciliation = false

    init(holding comments: [ReviewComment] = []) {
        saved = comments
    }

    /// Lets every held push answer.
    func releasePushes() {
        holdsPushes = false
    }

    func releaseReconciliation() {
        holdsReconciliation = false
    }

    func waitUntilReconciliationStarts() async -> Bool {
        for _ in 0..<1_000 where invocations.contains(.reconcile) == false {
            await Task.yield()
        }
        return invocations.contains(.reconcile)
    }

    /// Returns once `count` pushes have been made, because a change offers the review to the Mac
    /// without the reader waiting on it.
    ///
    /// **Bounded, so a push that never happens is a failed expectation rather than a hung suite.**
    /// Everything here runs on one actor, so a push that is coming arrives within a handful of turns.
    func waitUntilPushed(count: Int) async {
        for _ in 0..<1_000 where pushed.count < count {
            await Task.yield()
        }
    }

    func comments(in worktree: WorktreeID) -> [ReviewComment] {
        saved
    }

    func save(_ comments: [ReviewComment], in worktree: WorktreeID) {
        saved = comments
    }

    func push(_ comments: [ReviewComment], in worktree: WorktreeID) async -> ReviewSync {
        pushed.append(comments)
        while holdsPushes {
            await Task.yield()
        }
        // Record completion, because starting a push does not make the remote copy authoritative.
        invocations.append(.push)
        return pushAnswers
    }

    func reconcile(in worktree: WorktreeID) async -> [ReviewComment] {
        invocations.append(.reconcile)
        let anchors = Set(saved.map(\.anchor))
        let read = saved + onTheMac.filter { anchors.contains($0.anchor) == false }
        while holdsReconciliation {
            await Task.yield()
        }
        saved = read
        return read
    }

    enum Invocation: Equatable {
        case push
        case reconcile
    }
}
