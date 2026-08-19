import SwiftUI

/// Composition root for the phone and the iPad: the one Client target that may see a `Data`
/// target, because wiring implementations into the protocols every other target depends on is
/// its entire job.
///
/// The Xcode target is a thin `@main` shell over this scene, so nothing that a test would want to
/// reach lives in the app bundle.
public struct GranitaMobileScene: Scene {

    public init() {}

    public var body: some Scene {
        WindowGroup {
            NotPairedView()
        }
    }
}

/// The state the app is in before it has been paired with a Mac. It is the first thing a new
/// install shows, and it stays reachable from Settings after every device is revoked.
struct NotPairedView: View {

    var body: some View {
        ContentUnavailableView(
            "No Mac paired",
            systemImage: "laptopcomputer.slash",
            description: Text("Scan the pairing code from Granita on your Mac to start reviewing.")
        )
    }
}
