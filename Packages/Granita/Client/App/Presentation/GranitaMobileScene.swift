import SwiftUI

import ClientConnectionData
import ClientConnectionPresentation
import ClientConnectionUi

/// Composition root for the phone and the iPad: the one Client target that may see a `Data`
/// target, because wiring implementations into the protocols every other target depends on is
/// its entire job.
///
/// The Xcode target is a thin `@main` shell over this scene, so nothing a test would want to reach
/// lives in the app bundle.
public struct GranitaMobileScene: Scene {

    public init() {}

    public var body: some Scene {
        WindowGroup {
            // Selecting a Mac is pairing, and pairing needs a viewfinder — the scanner and its
            // screen have no frames, so the rows link to a destination this stack does not have and
            // tapping one does nothing, which is what tapping one already did.
            //
            // The client behind that screen is built and tested and is deliberately **not wired
            // here**: `MacPairing` reads a Mac's health, spends a code and keeps the token, and it
            // is composed by the pull request that draws the screen calling it. Wiring it now would
            // put a dependency in this root that nothing on screen can reach.
            NavigationStack {
                ServerDiscoveryScreen(
                    model: ClientConnectionModel(browsing: BonjourServerDiscovery())
                )
            }
            // The measure goes around the stack rather than around the screen, because iOS draws a
            // large title in the navigation bar and not in the content: framing the content alone
            // centres the rows under a title still pinned to the window's leading edge, which is the
            // misalignment this is here to remove.
            .frame(maxWidth: ServerDiscoveryView.contentWidth)
            .frame(maxWidth: .infinity)
        }
    }
}
