#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation

import ClientConnectionDomain

/// The pane, opened.
///
/// **The spelling is separated from the act that performs it**, which is the arrangement the Mac app
/// already uses and for the same reason: `url(of:)` is a pure function of its argument and stays
/// measured, while handing a URL to the system is a call on the running application that a test
/// process cannot make. Everything that can be *wrong* here is on the measured side.
public struct SystemSettingsOpener: SystemSettingsOpening {

    public init() {}

    @MainActor
    public func open(_ pane: SystemSettingsPane) {
        guard let url = Self.url(of: pane) else { return }
        #if canImport(AppKit)
        // Discarded deliberately: `open` reports whether the URL was handed over, not whether the pane
        // appeared, and there is nothing this app would do differently either way.
        _ = NSWorkspace.shared.open(url)
        #elseif canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    /// Where each pane lives.
    ///
    /// On iOS every case answers the app's own page, which is not a shortcut standing in for work not
    /// done: that page carries the Local Network and Camera switches together, so there is one
    /// destination and the argument has nothing to select.
    static func url(of pane: SystemSettingsPane) -> URL? {
        #if canImport(AppKit)
        switch pane {
        case .camera:
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Camera")
        case .localNetwork:
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocalNetwork")
        }
        #elseif canImport(UIKit)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}
