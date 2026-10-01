import AppKit
import SwiftUI

import ClientSettingsPresentation
import ServerMacDomain
import ServerMacPresentation
import ServerMacUi

/// Composition root for the unified Mac app.
///
/// The Xcode target is a thin `@main` shell. The status item serves phones, while the reader opens
/// independently and closing its window leaves the server running.
public struct GranitaMacScene: Scene {

    // `CommandLine.arguments` rather than anything injected, because this is the outermost
    // thing there is: a `Scene` is what the `@main` shell declares and nothing composes it.
    @State private var composition = MacComposition(
        launch: MacLaunchOptions(CommandLine.arguments.dropFirst())
    )

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                state: composition.model.serverState,
                onCopyAddress: { Task { await composition.model.copyAddress() } },
                // The one QR in the app is on Devices, so this is a door to it rather than a second
                // one. Declared here, beside the row that opens it, which is the rule the dead
                // discovery row cost eight releases to learn.
                onPairDevice: { composition.requestSettings(showing: .devices) },
                onOpenLocalNetworkSettings: {
                    Task { await composition.model.openSystemSettings(.localNetwork) }
                },
                // No pane, so the window opens on whichever one it was last left on.
                onOpenSettings: { composition.requestSettings(showing: nil) },
                onQuit: { NSApplication.shared.terminate(nil) },
                onShowWorktrees: composition.requestReader
            )
        } label: {
            MenuBarLabel(state: composition.model.serverState)
                .background {
                    SettingsOpener(
                        requests: composition.settingsRequests,
                        readerRequests: composition.readerRequests,
                        opensAtLaunch: composition.opensSettingsAtLaunch
                    )
                }
        }

        Settings {
            GranitaSettingsScreen(model: composition.model)
        }

        Window("Granita", id: Self.readerWindowId) {
            MacReaderRoot(composition: composition)
                .frame(minWidth: 640, minHeight: 480)
        }
        .defaultSize(width: 1260, height: 800)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commands { MacReaderCommands(model: composition.appearance) }
    }

    static let readerWindowId = "granita.reader"
}
