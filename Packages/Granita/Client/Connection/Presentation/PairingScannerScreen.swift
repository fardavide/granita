import SwiftUI

import ClientConnectionDomain
import ClientConnectionUi

/// The viewfinder, bound to the camera the model is reading and to the stack it moves within.
///
/// Two movements, and neither is an ordinary push. **The six words replace this screen rather than
/// sitting on top of it**, which is what puts the two credentials at one depth: no state is ever
/// behind another state, and coming back from either lands on the Mac. **So does the outcome** — a
/// receipt pushed over a viewfinder leaves a frozen frame and a spent code one back tap away, and a
/// reader who returns to it is looking at a screen that can no longer do anything.
struct PairingScannerScreen: View {

    private let model: ClientConnectionModel
    private let server: DiscoveredServer
    private let phone: ThisPhone

    @Binding private var path: NavigationPath

    init(
        model: ClientConnectionModel,
        server: DiscoveredServer,
        phone: ThisPhone,
        path: Binding<NavigationPath>
    ) {
        self.model = model
        self.server = server
        self.phone = phone
        _path = path
    }

    var body: some View {
        PairingScannerView(
            macName: server.name,
            state: model.pairing,
            onEnterWords: showTheWordsInstead,
            onOpenSettings: openSettings
        ) {
            CameraPreviewView(session: phone.cameraSession)
        }
        // The camera opens with the screen and closes with it: leaving cancels this, which ends the
        // run, which stops the session. A green dot lit over the list the reader went back to is
        // what the alternative looks like.
        .task { await model.readCode(on: server, as: phone.device) }
        .onChange(of: model.pairing) { _, pairing in
            guard pairing.needsTheOutcomeScreen else { return }
            replaceThisScreen(with: .theOutcome)
        }
    }

    private func showTheWordsInstead() {
        replaceThisScreen(with: .typeTheWords)
    }

    /// Swaps the top of the stack, so what is underneath stays the Mac rather than becoming this.
    private func replaceThisScreen(with step: PairingStep) {
        path.removeLast()
        path.append(step)
    }
}
