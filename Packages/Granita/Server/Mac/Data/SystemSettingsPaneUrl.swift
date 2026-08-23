import Foundation

import ServerMacDomain

/// Where each pane this app sends a reader to actually lives.
///
/// **Its own file, and the split is the point.** Everything in `AppKitSystemGestures` is a call on
/// the running application — `NSApp`, `NSPasteboard`, `NSWorkspace`, a modal panel — and none of it
/// can run in a test binary that has no application. This is the one part that is a pure function of
/// its argument, so it stays where a test can reach it rather than being exempted along with the
/// code around it.
///
/// It earns the separation by having the failure it does: a mistyped scheme or extension identifier
/// opens System Settings on its front page, which looks exactly like the app working and leaves the
/// reader hunting for a pane nobody named.
extension SystemSettingsPane {

    /// Force-unwrapped, and justified: both are literals here with no runtime input in them, so the
    /// optional can only be nil if the literal beside it is malformed — a compile-time editing
    /// mistake rather than a state to handle. Asserted for exactly that reason.
    var url: URL {
        switch self {
        case .localNetwork:
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocalNetwork")!
        case .loginItems:
            URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        }
    }
}
