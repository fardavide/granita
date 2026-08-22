import SwiftUI

import ClientConnectionDomain

/// What tapping a Mac says, until pairing has a screen.
///
/// **This exists because the alternative shipped and was the worst defect this product has had.**
/// The discovery rows are `NavigationLink`s and the stack declared no destination for them, so
/// tapping the Mac you opened the app to read did *nothing at all* — no push, no message, no
/// spinner. A reader taps again, taps harder, restarts the app, and concludes the product is broken
/// in a way they cannot describe. A control that looks operable must do something perceivable; if
/// what is behind it is not built, it says so. See the `no-dead-controls` skill.
///
/// It goes when pairing's own screens arrive, and it is deliberately not a stub: this is a real
/// state with real copy, drawn in this design's own empty-state idiom.
public struct PairingNotReadyView: View {

    private let server: DiscoveredServer

    public init(server: DiscoveredServer) {
        self.server = server
    }

    public var body: some View {
        ContentUnavailableView {
            Label("Pairing is not ready yet", systemImage: "qrcode.viewfinder")
        } description: {
            // Names the Mac, because the reader chose it and being told the app knows which one is
            // half of what makes this read as a state rather than as a failure. No action: pairing
            // needs a camera screen that does not exist, and there is nothing on this phone to tap
            // — which is this design's own rule for when an empty state gets a button.
            Text(
                """
                Granita can find \(server.name) on your network but cannot connect to it yet. \
                Pairing needs the camera, and that screen is still being built.
                """
            )
        }
        .navigationTitle(server.name)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
