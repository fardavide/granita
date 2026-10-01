import AppKit
import Foundation

@MainActor
public final class ReaderApplicationDelegate: NSObject, NSApplicationDelegate {

    public static let readerRequested = Notification.Name("granita.reader.requested")

    private let notificationCenter: NotificationCenter

    public override convenience init() {
        self.init(notificationCenter: .default)
    }

    public init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
        super.init()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        notificationCenter.post(name: Self.readerRequested, object: nil)
        return false
    }
}
