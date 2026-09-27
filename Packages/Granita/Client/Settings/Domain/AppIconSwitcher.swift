/// The system's answer to which icon this app shows on the Home Screen.
///
/// **The system is the source of truth, so nothing here is stored.** iOS remembers the alternate icon
/// across launches by itself and reports it back; a copy in this device's defaults could only ever be
/// a second answer that disagrees with the first after a restore.
///
/// Main-actor because the only implementation is `UIApplication`, which is.
public protocol AppIconSwitcher: Sendable {

    /// Whether this device can show another icon at all. False on a Mac.
    @MainActor var canChangeIcon: Bool { get }

    @MainActor func currentIcon() -> AppIcon

    /// Asks the system to show `icon`. On success iOS tells the reader itself, with an alert naming
    /// the change — that alert is the one feedback this setting needs, and it is not ours to draw.
    @MainActor func show(_ icon: AppIcon) async throws(AppIconRefusal)
}

/// The system declined to change the icon.
public struct AppIconRefusal: Error, Hashable, Sendable {

    /// The system's own description with its code, for small print — never for the sentence above it.
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }
}
