import Observation
import SwiftUI

import ClientConnectionDomain

/// Where the one stack this app has currently is.
///
/// **It is an object rather than a `@State` path on the container, because it holds rules**: a
/// pairing that worked replaces the screens that produced it rather than pushing past them, and a
/// launch opens at the Mac the reader was last reading rather than at the list of every Mac on the
/// network. A rule expressed inline in a view body is a rule no test can walk.
///
/// It used to hold another one — how wide the app was allowed to draw, released once the reader was
/// past the pairing spine — and that rule is gone. The pre-pairing screens lay themselves out with
/// stock SwiftUI now, at whatever width the window gives them. See `.ai/docs/decisions.md`.
@Observable
public final class PairingSpineNavigation {

    /// The stack's path.
    public var path: NavigationPath

    private let lastOpened: any LastOpenedMacPreference

    /// - Parameter path: where the stack opens when there is nothing to resume. The app passes an
    ///   empty one; the snapshot suite passes whichever push it is photographing, which is what lets
    ///   a baseline assert that a value put on this path comes back as a screen.
    public init(startingAt path: NavigationPath, remembering lastOpened: any LastOpenedMacPreference) {
        self.lastOpened = lastOpened
        // **A path that was given wins, and the resume only fills an empty one.** The app passes
        // nothing and means *open where I was*; the snapshot suite passes the push it is
        // photographing and means exactly that, and a resume that took it over would put a screen no
        // baseline asked for in front of the one it did — on whichever machine happened to hold a
        // record.
        if path.isEmpty, let mac = lastOpened.lastOpenedMac() {
            self.path = NavigationPath([ResumedMac(server: mac)])
        } else {
            self.path = path
        }
    }

    /// A pairing worked, so the Mac it produced replaces the screens that produced it.
    ///
    /// Assigned rather than appended, which is the whole of design §5's success: back then returns
    /// to the Mac list and never to a viewfinder holding a code that has already been spent.
    public func paired(with mac: PairedMac) {
        // Written down here as well as on the other route, because a reader who paired on this
        // launch is reading that Mac's worktrees on the next one — and a pairing is the strongest
        // statement either route makes about which Mac this phone is for.
        lastOpened.remember(DiscoveredServer(id: mac.instance, name: mac.name))
        path = NavigationPath([mac])
    }

    /// The reader is being sent back to the pairing screens for that Mac, so nothing is resumed.
    ///
    /// **This is the one control a revoked pairing offers**, which makes reaching it a statement
    /// that the credential behind the resume is the thing in question. A launch that went on
    /// assuming it would open a worktree list that can only fail — every time, until the reader
    /// paired again.
    public func pairAgain(with server: DiscoveredServer) {
        lastOpened.forget()
        path = NavigationPath([PairingAgain(server: server)])
    }

    /// The reader is reading that Mac's worktrees, which is where the next launch opens.
    public func opened(_ server: DiscoveredServer) {
        lastOpened.remember(server)
    }
}
