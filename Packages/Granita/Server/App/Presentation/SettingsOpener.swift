import AppKit
import SwiftUI

/// One invisible point of a window, whose only job is to be able to open Settings.
///
/// **TRAP, and SPEC §14 asks for this one to be implemented and verified rather than looked up.**
/// Opening Settings from a `MenuBarExtra` under `LSUIElement` fails three obvious ways:
/// `SettingsLink` is unreliable inside a menu, `@Environment(\.openSettings)` does nothing when no
/// render tree is holding it, and `NSApp.sendAction(showSettingsWindow:)` is deprecated. So the
/// menu records that Settings was asked for, and this — a 1×1 window declared *before* the
/// `Settings` scene, and therefore alive from launch — is what holds `openSettings` and calls it.
///
/// The activation dance is the second half. An `LSUIElement` app runs as `.accessory`, and an
/// accessory app cannot bring a window to the front: Settings would open behind everything, or
/// appear not to open at all. It becomes `.regular` for as long as Settings is up, and goes back
/// when that window closes — otherwise a Dock icon outlives the window that needed it.
struct SettingsOpener: View {

    let requests: Int

    /// Whether to open Settings without waiting to be asked.
    ///
    /// The menu is otherwise the only route in, which makes a behavioural test's first act clicking
    /// a status item — a step that can fail for reasons having nothing to do with what the test is
    /// asserting. Through the same call the menu uses, so what a test opens is what a reader opens.
    let opensAtLaunch: Bool

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .background(InvisibleWindow())
            .task {
                // After this window's render tree exists, which is the whole reason this view is
                // the one holding `openSettings`.
                if opensAtLaunch { present() }
            }
            .onChange(of: requests) { present() }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
                // Asked of the app rather than of the window that closed: SwiftUI's Settings window
                // is not an `NSPanel`, its title is localised, and its identifier is an
                // implementation detail — so "was that the settings window" has no honest answer.
                // "Is anything left worth being a regular app for" does, and it is the question the
                // Dock icon is really about. Next runloop turn, because the window that is closing
                // is still in the list during the notification.
                Task { @MainActor in
                    let visible = NSApp.windows.filter { $0.isVisible && $0.alphaValue > 0 }
                    if visible.isEmpty {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
            }
    }

    /// The activation dance, in one place because two things now perform it.
    ///
    /// An `LSUIElement` app runs as `.accessory`, and an accessory app cannot bring a window to the
    /// front: Settings would open behind everything, or appear not to open at all.
    private func present() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        openSettings()
    }
}

// MARK: -

/// Takes the window this view is in out of sight without taking it out of existence.
///
/// A one-point window is still a window: SwiftUI gives it a title bar, so what lands on screen is a
/// 1×33 sliver rather than nothing. Closing it is not an option — the render tree it holds is the
/// whole reason it exists — so it is made transparent, deaf to the mouse, and absent from the
/// Window menu instead.
private struct InvisibleWindow: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            guard let window = view.window else { return }
            window.alphaValue = 0
            window.ignoresMouseEvents = true
            window.isExcludedFromWindowsMenu = true
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
