import AppKit
import SwiftUI

import ServerMacData

/// Holds the window-opening actions in the status label's persistent render tree.
///
/// The unified app is regular, so it needs no accessory activation policy or invisible window.
/// Menus and Dock reopen requests use the same anchor, including before either window is open.
struct SettingsOpener: View {

    let requests: Int
    let readerRequests: Int

    /// Whether to open Settings without waiting to be asked.
    ///
    /// The menu is otherwise the only route in, which makes a behavioural test's first act clicking
    /// a status item — a step that can fail for reasons having nothing to do with what the test is
    /// asserting. Through the same call the menu uses, so what a test opens is what a reader opens.
    let opensAtLaunch: Bool

    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                // The status label exists at launch even when the reader stays closed.
                if opensAtLaunch { present() }
            }
            .onChange(of: requests) { present() }
            .onChange(of: readerRequests) {
                NSApp.activate()
                openWindow(id: GranitaMacScene.readerWindowId)
            }
            .onReceive(NotificationCenter.default.publisher(for: ReaderApplicationDelegate.readerRequested)) { _ in
                NSApp.activate()
                openWindow(id: GranitaMacScene.readerWindowId)
            }
    }

    private func present() {
        NSApp.activate()
        openSettings()
    }
}
