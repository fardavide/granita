import ClientConnectionUi
import SwiftUI

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
            NotPairedView(onStartPairing: {})
        }
    }
}
