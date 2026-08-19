import SwiftUI

/// Composition root for the menu bar app: the one Server Ui target, and the only one that may see
/// a `Data` target.
///
/// The Xcode target is a thin `@main` shell over this scene. Granita has no Dock icon and no main
/// window — `LSUIElement` is true — so the menu bar extra is the whole of its presence.
public struct GranitaMacScene: Scene {

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            // A MenuBarExtra label renders Text and Image reliably and little else, so the
            // dirty-worktree count will arrive here as a Text beside the icon rather than as a
            // badge modifier.
            Image(systemName: "arrow.trianglehead.branch")
        }
    }
}

struct MenuBarContent: View {

    var body: some View {
        Button("Quit Granita") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
