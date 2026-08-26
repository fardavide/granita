import ClientConnectionDomain

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
}
