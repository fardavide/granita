import AppKit
import ServerMacDomain
import ServerMacPresentation
import ServerMacUi
import SwiftUI

/// Composition root for the menu bar app: the only Server target that may see a `Data` target.
///
/// The Xcode target is a thin `@main` shell over this scene. Granita has no Dock icon and no main
/// window — `LSUIElement` is true — so the menu bar extra is the whole of its presence.
public struct GranitaMacScene: Scene {

    // `CommandLine.arguments` rather than anything injected, because this is the outermost
    // thing there is: a `Scene` is what the `@main` shell declares and nothing composes it.
    @State private var composition = MacComposition(
        launch: MacLaunchOptions(CommandLine.arguments.dropFirst())
    )

    public init() {}

    public var body: some Scene {
        // Declared BEFORE the Settings scene, and that order is load-bearing. See `SettingsOpener`.
        Window(Text(verbatim: ""), id: Self.openerWindowId) {
            SettingsOpener(
                requests: composition.settingsRequests,
                opensAtLaunch: composition.opensSettingsAtLaunch
            )
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
