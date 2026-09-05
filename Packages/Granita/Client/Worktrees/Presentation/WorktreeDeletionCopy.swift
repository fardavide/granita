import ClientConnectionDomain
import ClientWorktreesDomain

/// The two things the sidebar's one alert ever asks about.
///
/// One modifier serves both, because two `.alert` modifiers on a single view is the shape where only
/// one ever presents — and the one that would lose is the confirmation in front of the only control
/// here that destroys anything.
enum WorktreeAlertPrompt: Hashable, Sendable {
    case confirmDeletion(WorktreeDeletionSubject)
    case refusal(WorktreeWriteRefusal)
}

extension WorktreeAlertPrompt? {

    /// **The name in full and never truncated**, because the mistake the confirmation exists to
    /// prevent is destroying the *wrong* row — destroying the right one is what the reader asked
    /// for, so the identifying string is the load-bearing part.
    ///
    /// Optional-rooted because `nil` is a real case rather than a defensive one: the title is read
    /// once more as the alert cross-fades away, and without a sentence there it fades to an empty
    /// bar.
    var title: String {
        switch self {
        case .confirmDeletion(let subject): "Delete “\(subject.displayName)”?"
        case .refusal(.edit): "Your Mac would not make that change"
        case .refusal(.deletion(.worktreeNotDeletable)): "Your Mac would not delete it"
        case .refusal(.deletion): "Granita could not tell whether it was deleted"
        case nil: "Delete this worktree?"
        }
    }
}

extension WorktreeAlertPrompt {

    var message: String {
        switch self {
        case .confirmDeletion(let subject):
            subject.cost

        // Renaming and pinning both leave the row exactly where it was when they fail, so without
        // this the swipe is a control that appears to have done nothing.
        case .refusal(.edit):
            "The row is still as it was. Trying again usually works."

        case .refusal(.deletion(let failure)):
            // Matched rather than switched, because a `switch` over every `ApiFailure` here would
            // need the `default:` this project forbids, over fourteen cases that mean one thing to
            // this screen.
            if case .worktreeNotDeletable = failure {
                """
                Nothing was deleted and the worktree is still there. Your Mac will not remove this \
                one: it is the project’s own checkout rather than one of its worktrees.
                """
            } else {
                // **The honest sentence rather than the reassuring one.** A request that did not
                // finish may have arrived and this phone cannot tell. Saying so is only useful
                // because the advice that follows is true — a second attempt on a worktree that has
                // already gone is treated as success and simply drops the row.
                """
                The request did not finish, so the worktree may or may not still be on your Mac. \
                Deleting it again is safe: if it has already gone, the row simply goes.
                """
            }
        }
    }
}

/// What the confirmation says is about to stop existing.
///
/// **Here rather than in the alert's body**, because there is no `Ui` test target in this package
/// and an alert presents into a window of its own that no raster includes — so a sentence written
/// inside the view is a sentence nothing in this repository can hold to its words. Internal, so the
/// suite reaches it through `@testable import`, and one file to delete when the design comes back
/// with the words it wants.
extension WorktreeDeletionSubject {

    /// The three sentences the reader is agreeing to, branched on what the row is showing, and a
    /// fourth where the Mac is holding a lock this deletion will override.
    ///
    /// The `+n −m` spelling is the row's own, so the alert reads as being about the row that was
    /// pressed rather than about worktrees in general.
    ///
    /// **Plain interpolation rather than a format style**, following `WorktreeAge.label` and for its
    /// reason: a format style reaches the environment's locale, and these strings are asserted by a
    /// host test with no locale pinned. The visible cost is that the alert reads `+1204` where the
    /// row reads `+1,204`, and only above 999.
    var cost: String {
        guard isLocked else { return costOfTheWork }
        // **Last rather than first**, because the cost is what the reader is deciding on and the lock
        // is a fact about what the deletion has to get past to do it. It is stated at all because a
        // lock used to refuse the deletion outright: the reader is now the one overriding it, and a
        // reader cannot override something nobody told them about.
        return """
        \(costOfTheWork)

        Your Mac has this worktree locked — Claude Code locks the ones it makes. Deleting it here \
        goes ahead anyway.
        """
    }

    private var costOfTheWork: String {
        switch stats {
        // No branch sentence: an unborn head has no commits for a branch to keep.
        case .noCommitsYet:
            """
            Nothing in this worktree has ever been committed, so all of it goes when the folder \
            does. Nothing can bring it back.
            """

        // Granita only sees what git reports as changed, and `worktree remove --force` takes the
        // whole directory — so a worktree with nothing to review still has the ignored files in it.
        case .noChanges:
            """
            Granita sees no uncommitted changes here, but the whole folder goes — including the \
            files git ignores, like local settings and build output. The branch stays on your Mac.
            """

        case .changed(let filesChanged, let insertions, let deletions):
            """
            \(filesChanged == 1 ? "1 file here has" : "\(filesChanged) files here have") changes \
            that were never committed: +\(insertions) −\(deletions). Deleting the worktree deletes \
            them, and nothing can bring them back. The branch stays on your Mac.
            """
        }
    }
}
