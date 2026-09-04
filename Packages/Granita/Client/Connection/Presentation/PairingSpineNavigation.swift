import Observation
import SwiftUI

import ClientConnectionDomain

/// Where the one stack this app has currently is.
///
/// **It is an object rather than a `@State` path on the container, because it holds a rule**: a
/// pairing that worked replaces the screens that produced it rather than pushing past them, and a
/// rule expressed inline in a view body is a rule no test can walk.
///
/// It used to hold a second one — how wide the app was allowed to draw, released once the reader was
/// past the pairing spine — and that rule is gone. The pre-pairing screens lay themselves out with
/// stock SwiftUI now, at whatever width the window gives them. See `.claude/docs/decisions.md`.
@Observable
public final class PairingSpineNavigation {

    /// The stack's path.
    public var path: NavigationPath

    /// - Parameter path: where the stack opens. The app opens at the Mac list; the snapshot suite
    ///   opens at whichever push it is photographing.
    public init(startingAt path: NavigationPath) {
        self.path = path
    }

    /// A pairing worked, so the Mac it produced replaces the screens that produced it.
    ///
    /// Assigned rather than appended, which is the whole of design §5's success: back then returns
    /// to the Mac list and never to a viewfinder holding a code that has already been spent.
    public func paired(with mac: PairedMac) {
        path = NavigationPath([mac])
    }
}
