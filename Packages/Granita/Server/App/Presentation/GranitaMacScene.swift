import AppKit
import ServerMacPresentation
import ServerMacUi
import SwiftUI

/// Composition root for the menu bar app: the only Server target that may see a `Data` target.
///
/// The Xcode target is a thin `@main` shell over this scene. Granita has no Dock icon and no main
/// window — `LSUIElement` is true — so the menu bar extra is the whole of its presence.
public struct GranitaMacScene: Scene {

    @State private var composition = MacComposition()

    public init() {}

    public var body: some Scene {
        // Declared BEFORE the Settings scene, and that order is load-bearing. See `SettingsOpener`.
        Window(Text(verbatim: ""), id: Self.openerWindowId) {
            SettingsOpener(requests: composition.settingsRequests)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)

        MenuBarExtra {
            MenuBarContent(
                state: composition.model.serverState,
                onOpenSettings: { composition.requestSettings() },
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        } label: {
            MenuBarLabel(state: composition.model.serverState)
        }

        Settings {
            GranitaSettingsScreen(model: composition.model)
        }
    }

    static let openerWindowId = "granita.settings.opener"
}
