import SwiftUI

import ClientConnectionData
import ClientConnectionDomain
import ClientConnectionPresentation
import ClientConnectionUi
import CorePairingDomain

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
            // and pairing needs a viewfinder — the scanner and its screen have no frames, so the
            // rows link to a destination this stack does not have and tapping one does nothing,
            // which is what tapping one did when the callback was a no-op. What is wired below is
            // everything behind that screen: the model can already read a Mac's health, spend a
            // code and keep the token.
            NavigationStack {
                ServerDiscoveryScreen(model: model())
            }
            // The measure goes around the stack rather than around the screen, because iOS draws a
            // large title in the navigation bar and not in the content: framing the content alone
            // centres the rows under a title still pinned to the window's leading edge, which is the
            // misalignment this is here to remove.
            .frame(maxWidth: ServerDiscoveryView.contentWidth)
            .frame(maxWidth: .infinity)
        }
    }

    private func model() -> ClientConnectionModel {
        ClientConnectionModel(
            browsing: BonjourServerDiscovery(),
            joining: MacPairing(
                tokens: KeychainPairingTokenStore(),
                // One session per Mac, pinned to the key its own pairing link carried. Built here
                // and not held, because the fingerprint arrives with the link and a session built
                // for one Mac must be incapable of reaching another.
                handshake: { link in
                    HttpServerPairing(
                        macAt: address(of: link),
                        transport: UrlSessionHttpTransport(pinnedTo: link.fingerprint)
                    )
                }
            )
        )
    }
}

/// Where a link says its Mac is.
///
/// A host that will not go into a URL is a scanned code that is damaged, and the fallback treats it
/// as one: an address nothing answers on, which surfaces as "could not reach your Mac" rather than
/// as a crash. That is the same sentence a reader would get from pointing the camera at the right
/// screen on the wrong network, which is the closest true thing this app can say.
private func address(of link: PairingLink) -> URL {
    var components = URLComponents()
    components.scheme = "https"
    components.host = link.host
    components.port = link.port
    return components.url ?? URL(filePath: "/nowhere")
}
