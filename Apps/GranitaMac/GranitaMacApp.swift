import ServerAppMain
import SwiftUI

/// Thin `@main` shell. Everything worth testing lives in the package, so this file holds the one
/// thing that cannot: the entry point itself.
@main
struct GranitaMacApp: App {
    @NSApplicationDelegateAdaptor(GranitaApplicationDelegate.self) private var delegate

    var body: some Scene {
        GranitaMacScene()
    }
}
