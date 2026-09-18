/// What started a read of the change set, which is what decides whether the read reports itself in
/// the toolbar.
///
/// **There are two ways in and not the worktree list's four, and the two that are missing are calls
/// rather than omissions.** The list re-reads when the app comes back to the front; this screen
/// deliberately does not, because replacing every entry under a reader halfway down a scroll is the
/// unasked-for movement `SPEC.md` §10 forbids. And the list separates a retry from an appearance
/// because a retry happens over rows that are still on screen; here a retry is only ever offered by
/// the failure screen, which has no change set behind it and is already a spinner and a sentence.
public enum DiffReadTrigger: Hashable, Sendable {

    /// The screen's own `.task`, which re-runs every time the screen appears. Nobody asked for it.
    case appearance

    /// The reader pulling the scroll down, which the scroll reports for itself.
    case pullToRefresh
}
