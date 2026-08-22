import AppKit
import Foundation
import SwiftUI

import ServerMacUi

/// Granita's Settings window.
///
/// Design §2 gives it five tabs rather than the specification's four, with Advanced **last**. The
/// connection log is not an advanced setting — it is a live view of what is happening to this Mac,
/// the only panel with a reason to be reopened, and the one thing here read under pressure — so it
/// gets its own tab, and Advanced goes last because of what shares it: `Reset All Data`. A panel
/// opened while annoyed should not be one mis-click from the button that unpairs every device.
///
/// The three that are not built yet are not declared. A tab bar with placeholders in it is a worse
/// answer than a tab bar that grows: the order above is what the tabs land into, and Advanced stays
/// last throughout.
///
/// Restoring the last-used tab, and selecting Projects on a first run, land with the tabs that make
/// either question answerable — a remembered selection is a preference for a set of tabs that does
/// not exist yet.
public struct GranitaSettingsScreen: View {

    /// Fixed, not a minimum, and read by the window as well as by the test that asserts it.
    ///
    /// The height comes from Devices: the pairing payload is about 140 bytes once the digest is
    /// percent-encoded, which in byte mode at error correction M is a QR of 49 to 53 modules — at
    /// the 4pt module that scans from arm's length, plus a four-module quiet zone, 236 to 244pt
    /// square. Stacked with the six words, the countdown and two paired devices, that pane needs
    /// 560pt. The window does not resize per tab, because between a 560pt QR pane and a three-row
    /// General pane the jump reads as a glitch.
    public static let windowSize = CGSize(width: 620, height: 560)

    private let model: ServerMacModel

    public init(model: ServerMacModel) {
        self.model = model
    }

    public var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView(
                    state: model.serverState,
                    servingSince: model.servingSince,
                    loginItem: model.loginItem,
                    // Read and write derived from the same property, so the toggle cannot disagree
                    // with the sentence under it. Registration is asynchronous and can be refused,
                    // so the write is a request rather than an assignment — what the toggle shows
                    // next is whatever the system allowed.
                    opensAtLogin: Binding(
                        get: { model.loginItem == .on },
                        set: { enabled in Task { await model.setLoginItem(enabled: enabled) } }
                    ),
                    onCopyAddress: Self.copy,
                    onRestart: { Task { await model.restartServer() } },
                    onOpenLocalNetworkSettings: { Self.open(Self.localNetworkSettings) },
                    onOpenLoginItems: { Self.open(Self.loginItemsSettings) }
                )
                .task { await model.loadLoginItem() }
            }

            Tab("Connections", systemImage: "point.3.connected.trianglepath.dotted") {
                // The clock the rows are measured against. A row's elapsed time is a value the view
                // is handed rather than one it derives, which is what lets a baseline photograph
                // it — so something has to move it, and a schedule that re-renders on the minute is
                // both the cheapest thing that can and exactly as often as a row changes: the
                // coarsest unit below an hour is a minute.
                TimelineView(.everyMinute) { clock in
                    ConnectionLogView(attempts: model.connectionAttempts, now: clock.date)
                }
                .task { await model.followConnections() }
            }

            Tab("Advanced", systemImage: "gearshape.2") {
                AdvancedSettingsView(
                    git: model.gitInstallation,
                    dataFolderUrl: model.dataFolderUrl,
                    projectCount: model.storedProjectCount,
                    deviceCount: model.storedDeviceCount,
                    onRevealDataFolder: { Self.reveal(model.dataFolderUrl) },
                    onResetAllData: { Task { await model.resetAllData() } }
                )
                .task {
                    // Both on opening rather than at launch. Running git is a subprocess and the
                    // counts are a disk read, and neither is worth doing for a tab nobody has
                    // looked at — while both are worth re-doing every time this one is, because
                    // git can be installed and projects added while Granita is running.
                    await model.loadGitInstallation()
                    await model.loadStoredCounts()
                }
            }
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
    }

    /// AppKit rather than a protocol with a fake behind it. Both of these are one-line system
    /// gestures with nothing to decide and nothing a test would assert; a seam here would be an
    /// abstraction invented for a future nobody asked for.
    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Finder, with the folder selected rather than opened, which is what "Reveal" means everywhere
    /// else on this machine.
    private static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Privacy & Security › Local Network, and Login Items, addressed directly. Without the first
    /// one an `NWError` code is the whole explanation a person gets for an app that does nothing.
    // Force-unwrapped, and justified: both are literals in this file with no runtime input in
    // them, so the optional can only be nil if the literal beside it is malformed — which is a
    // compile-time editing mistake and not a state to handle.
    private static let localNetworkSettings = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocalNetwork"
    )!

    private static let loginItemsSettings = URL(
        string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
    )!
}
