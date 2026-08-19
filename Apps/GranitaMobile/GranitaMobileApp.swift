import ClientAppPresentation
import SwiftUI

/// Thin `@main` shell. Everything worth testing lives in the package, so this file holds the one
/// thing that cannot: the entry point itself.
@main
struct GranitaMobileApp: App {

    var body: some Scene {
        GranitaMobileScene()
    }
}
