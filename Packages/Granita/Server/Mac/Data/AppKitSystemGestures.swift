import AppKit
import Foundation

import ServerMacDomain

/// The folder picker, which is AppKit and therefore not a view's business.
///
/// **The activation dance is the same trap `SettingsOpener` exists for, and SPEC §9 names this half
/// of it too.** An `LSUIElement` app runs as `.accessory`, and an accessory app cannot bring a panel
/// to the front — the panel opens behind everything, or appears not to open at all. It costs one
/// line because the Settings window that raised it has already switched the app to `.regular`;
/// activating anyway is what keeps it true when that stops being so.
public struct AppKitFolderPicker: FolderPicking {

    public init() {}

    public func pickFolder(prompt: String, message: String) async -> URL? {
        await MainActor.run {
            NSApp.activate()
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = prompt
            panel.message = message
            return panel.runModal() == .OK ? panel.url : nil
        }
    }
}

/// The one-way gestures, performed.
///
/// Every line here is a call on the running application, which is why the pane spellings live in
/// their own file beside this one: those are a pure function and stay measured, while this is
/// unrunnable in a test binary that has no `NSApp` — see `decisions.md`.
public struct AppKitSystemGestures: SystemGestures {

    public init() {}

    public func copyToPasteboard(_ text: String) async {
        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    public func revealInFinder(_ url: URL) async {
        await MainActor.run {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    public func openSystemSettings(_ pane: SystemSettingsPane) async {
        let url = pane.url
        await MainActor.run {
            // Discarded deliberately: `open` reports whether the URL was handed over, not whether
            // the pane appeared, and there is nothing this app would do differently either way.
            _ = NSWorkspace.shared.open(url)
        }
    }

    /// **Found by bundle identifier rather than by path**, because `/System/Applications/Utilities`
    /// is a location Apple has moved before and a hard-coded path that stops resolving is a button
    /// that silently does nothing. The path is the fallback rather than the answer.
    public func openConsole() async {
        await MainActor.run {
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.consoleBundleIdentifier)
                ?? URL(filePath: "/System/Applications/Utilities/Console.app")
            _ = NSWorkspace.shared.open(url)
        }
    }

    public func quit() async {
        await MainActor.run {
            NSApp.terminate(nil)
        }
    }

    private static let consoleBundleIdentifier = "com.apple.Console"
}
