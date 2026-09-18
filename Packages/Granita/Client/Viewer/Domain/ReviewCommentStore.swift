import CoreDiffDomain
import CoreReviewDomain

/// Where the comments a reader has written live between writing them and copying them.
///
/// **On the phone for now, and that is a scheduling call rather than the right home.** A review
/// belongs on the Mac beside the worktree it is about — it survives a new phone, it can be read by
/// something other than the app that wrote it, and `SPEC.md` §9 already says the store protocol
/// exists so v2's comments can grow the data. Moving it there is a wire change, new routes and a
/// contract version, which is a slice of its own: see
/// [issue #64](https://github.com/fardavide/granita/issues/64). Nothing in this protocol is on the
/// wire, so nothing here has to be rewritten when it moves — the model keeps calling this and the
/// composition root hands it a different conformer.
///
/// **Keyed per worktree**, because that is what a review is of. Two agents in two checkouts of one
/// project are two reviews, and one key for both would hand each reader the other's notes.
///
/// Synchronous, like the sidebar's own preferences: this is a read of local state that answers
/// immediately, and a suspension point here would put an `await` in front of every keystroke.
public protocol ReviewCommentStore: Sendable {

    func comments(in worktree: WorktreeID) -> [ReviewComment]

    /// Replaces the whole review, which is also how it is cleared.
    ///
    /// The whole set rather than one comment at a time: a review is small, the model already holds
    /// all of it, and a per-comment interface would make *Clear* a loop with a half-cleared state in
    /// the middle of it.
    ///
    /// **Stays synchronous, and stays local.** This is the write that makes a comment survive the
    /// system ending the app, so it must not wait on a network — a comment is saved by the time the
    /// composer's *Done* returns, and that promise is older than the Mac holding anything.
    func save(_ comments: [ReviewComment], in worktree: WorktreeID)

    /// Offers the review to the Mac and answers with how much of it landed.
    ///
    /// Separate from `save` because they answer different questions and fail differently: saving is
    /// this phone keeping its own promise, pushing is the Mac accepting it. A refused push loses
    /// nothing — the review is still here, and the copy that matters never waits for this.
    func push(_ comments: [ReviewComment], in worktree: WorktreeID) async -> ReviewSync

    /// Reads what the Mac holds and merges it with what this phone wrote.
    ///
    /// **A union in document order, deliberately anonymous.** Two devices reviewing one worktree are
    /// two halves of one review: comments are anchored to different lines, so the union is almost
    /// always exactly what the reader wants, and swipe-to-delete is already the control for the
    /// rest. Naming which device wrote which comment would start making this a review with two
    /// authors, which is a v2 shape nobody asked for.
    func reconcile(in worktree: WorktreeID) async -> [ReviewComment]
}
