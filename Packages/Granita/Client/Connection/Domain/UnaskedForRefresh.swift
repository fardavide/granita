/// When a read the reader never asked for is worth saying out loud.
///
/// **Both screens that read from a Mac re-read on every appearance**, because a `.task` is re-run
/// each time its view comes back. That is the right behaviour — a worktree list a reader returns to
/// should not be the one they left — and until 0.13.0 it happened in complete silence, which is the
/// thing this type exists to end.
///
/// It lives in the connection unit's `Domain` rather than in either feature's because both the
/// worktree list and the diff screen answer the same question with the same number, and a constant
/// spelled twice is two answers waiting to disagree.
public enum UnaskedForRefresh {

    /// How long such a read runs before a spinner appears beside the title.
    ///
    /// **A threshold rather than nothing, and that is what makes the indicator worth having.** Most
    /// of these reads answer on a LAN in well under this, so announcing every one would put a
    /// spinner into the bar and take it out again each time a reader came back from a worktree —
    /// motion they did not cause, reporting a wait they never had. A read that answers inside this
    /// window is one nobody needed telling about. It also keeps the resting screens resting: the
    /// README's own published screenshots are rendered from a Mac that answers instantly, and
    /// without a threshold every one of them advertises an app that is perpetually loading.
    ///
    /// **It is not design §8's ten seconds**, which is a different question asked of a different
    /// screen: that one is *this is taking unusually long*, said about a wait the reader is already
    /// watching. This one is *there is a wait at all*.
    public static let announcementDelay: Duration = .milliseconds(500)
}
