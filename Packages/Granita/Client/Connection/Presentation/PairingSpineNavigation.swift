import Observation
import SwiftUI

import ClientConnectionDomain
import ClientConnectionUi

/// Where the one stack this app has currently is, and the one thing that follows from it: how wide
/// the app is allowed to draw.
///
/// **It is an object rather than two `@State` properties on the container, because it holds a rule.**
/// Design §5 clamps everything before a paired Mac to a 420pt centred column and §2 gives the
/// worktree list a split view whose sidebar alone is 320, so the width is a decision taken from a
/// sequence of pushes and pops — and a decision expressed as flags in a view body is a decision no
/// test can walk. 0.4.1 expressed it that way in the composition root, released the measure on the
/// route a reader takes once, and left the route they take daily reading an iPad's worktrees through
/// a phone-shaped slot. See `.claude/docs/decisions.md`.
@Observable
public final class PairingSpineNavigation {

    /// The stack's path.
    ///
    /// Computed over the stored one so that **emptying it puts the measure back**, which is the
    /// whole of what a `didSet` would be for: back out of a worktree list is the system's own
    /// button, and nothing of ours is told it was pressed. The path going empty is the only signal
    /// there is that the reader is at the Mac list again.
    public var path: NavigationPath {
        get { stack }
        set {
            stack = newValue
            if stack.isEmpty {
                hasLeftTheSpine = false
            }
        }
    }

    /// How wide the container may draw, which is the one question this object exists to answer.
    ///
    /// The measure goes around the navigation container rather than around the screen inside it, and
    /// that is design §5's own call: iOS draws a large title in the navigation bar rather than in the
    /// content, so a frame applied inside centres the rows and leaves the title pinned to the
    /// window's leading edge — the exact misalignment the measure exists to remove.
    public var contentWidth: CGFloat {
        hasLeftTheSpine ? .infinity : ServerDiscoveryView.contentWidth
    }

    private var stack: NavigationPath

    /// Whether the reader is past the pairing spine and into a worktree list.
    ///
    /// It cannot be *read* off the path, which is why it is held. `NavigationPath` is type-erased on
    /// purpose — that is what lets every destination be declared beside the link that reaches it —
    /// and a Mac already paired with and a Mac about to be paired with are the same value at depth
    /// one. Which of the two a push reaches is decided when the destination is built, from a set
    /// that changes, so there is nothing here to derive it from.
    private var hasLeftTheSpine = false

    /// - Parameter path: where the stack opens. The app opens at the Mac list; the snapshot suite
    ///   opens at whichever push it is photographing.
    public init(startingAt path: NavigationPath) {
        stack = path
    }

    /// A pairing worked, so the Mac it produced replaces the screens that produced it.
    ///
    /// Assigned rather than appended, which is the whole of design §5's success: back then returns
    /// to the Mac list and never to a viewfinder holding a code that has already been spent.
    public func paired(with mac: PairedMac) {
        path = NavigationPath([mac])
    }

    /// A destination past the pairing spine is on screen, so the column gives way to the window.
    ///
    /// **Both routes out of the spine call this and they are the only two**: a Mac just paired with,
    /// and a Mac this phone already knew. Naming the arrival rather than either route is what stops
    /// a third one being added with the measure left behind — which is exactly how the second one
    /// was added.
    public func openedAWorktreeList() {
        hasLeftTheSpine = true
    }
}
