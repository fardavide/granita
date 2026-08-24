import Foundation

import ServerMacDomain

/// The remembered pane, in this Mac's user defaults.
///
/// Defaults rather than the JSON document, because this is a fact about one app's window and the
/// document is shared with the executable. It is also the one thing here that may be lost without
/// consequence: a reader who moves their preferences to a new Mac lands on Projects, which is what a
/// first run does anyway.
// `UserDefaults` is documented as thread-safe and carries no `Sendable` conformance, so the
// invariant the compiler cannot see is upheld by the class itself rather than by anything here.
public struct UserDefaultsSettingsTabMemory: SettingsTabMemory, @unchecked Sendable {

    /// The one string this file writes, exposed because it is a storage contract rather than an
    /// implementation detail: a test asserting what happens to a value no release ever wrote has to
    /// be able to write one.
    public static let defaultsKey = "granita.settings.lastUsedTab"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// A word that names no pane reads as nothing at all rather than as a failure. It can only come
    /// from a defaults file edited by hand or written by a release that spelled a pane differently,
    /// and in both cases the honest answer is the one a Mac that has never opened the window gives.
    public func lastUsedTab() -> SettingsTab? {
        defaults.string(forKey: Self.defaultsKey).flatMap(SettingsTab.init(rawValue:))
    }

    public func remember(_ tab: SettingsTab) {
        defaults.set(tab.rawValue, forKey: Self.defaultsKey)
    }
}
