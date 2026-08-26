import ClientConnectionDomain
import CoreDiffDomain

/// What the diff screen has to show, which is four things and not one list.
///
/// It lives in `Domain` rather than beside the model for the reason `WorktreeSidebarState` does: the
/// view that renders it may not see `Presentation`, and a state the view layer cannot name is a
/// state the view layer branches on by inference instead.
public enum ContinuousDiffState: Hashable, Sendable {

    case loading

    case failed(ApiFailure)

    /// The worktree is clean. **Reachable on purpose** rather than by accident: design §2's sidebar
    /// offers *Show them anyway*, so opening a worktree with nothing in it is something a reader
    /// chooses to do.
    case nothingChanged

    case reading([ContinuousDiffEntry])

    /// Where the scroll starts when nobody has asked it to go anywhere.
    ///
    /// **Stated rather than left to settle.** The scroll is positioned by file identity, and a
    /// position binding that begins empty is one the scroll fills in for itself as it lays out —
    /// which is a value that arrives on its own schedule, and the baseline of a screen with this
    /// scroll in it moved between two runs of unchanged code because of it. Starting at the first
    /// file is what the reader gets either way; saying so makes it a fact.
    public var firstFile: FileID? {
        switch self {
        case .reading(let entries): entries.first?.id
        case .loading, .failed, .nothingChanged: nil
        }
    }
}
