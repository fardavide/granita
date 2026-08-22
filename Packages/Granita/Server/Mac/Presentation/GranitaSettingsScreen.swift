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
/// Three of the five are not built yet and are therefore not declared. A tab bar with placeholders
/// in it is a worse answer than a tab bar that grows: the order above is what the tabs land into,
/// and Advanced stays last throughout.
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

            Tab("Advanced", systemImage: "gearshape.2") {
                ConnectionLogView(attempts: model.connectionAttempts)
                    .task { await model.followConnections() }
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
