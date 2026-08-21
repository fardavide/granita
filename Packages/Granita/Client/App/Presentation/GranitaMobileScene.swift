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
            // No `navigationDestination` for a discovered server yet. Selecting a Mac is pairing,
            // and pairing is the milestone that brings the Keychain identity and the QR code with
            // it — so the rows link to a destination this stack does not have, and tapping one does
            // nothing, which is what tapping one did when the callback was a no-op.
            NavigationStack {
                ServerDiscoveryScreen(
                    viewModel: ServerDiscoveryViewModel(discovery: BonjourServerDiscovery())
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
