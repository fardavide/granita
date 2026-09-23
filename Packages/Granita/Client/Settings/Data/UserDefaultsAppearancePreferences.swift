import Foundation

import ClientSettingsDomain
import ClientViewerDomain

/// The two device-local settings, in this phone's user defaults.
///
/// Defaults rather than anything the Mac holds, and rather than the store the review's settings go
/// to: neither of these changes what a review says, so there is nothing for a second device to read
/// and nothing to reconcile. It is also the pair that may be lost without consequence — a reader who
/// restores to a new phone lands on what a first run gives, which is their system appearance and
/// Xcode's colours.
// `UserDefaults` is documented as thread-safe and carries no `Sendable` conformance, so the
// invariant the compiler cannot see is upheld by the class itself rather than by anything here.
public struct UserDefaultsAppearancePreferences: AppearancePreferences, @unchecked Sendable {

    /// Exposed because they are a storage contract rather than an implementation detail: a test
    /// asserting what happens to a value no release ever wrote has to be able to write one.
    public static let appearanceKey = "granita.appearance.app"
    public static let codeThemeKey = "granita.appearance.codeTheme"
    public static let sideBySideKey = "granita.appearance.sideBySide"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// A word that names no appearance falls back rather than failing, which is the same call
    /// `WorktreeListPreferences` makes and for the same reason: the only ways to get one are a
    /// defaults file edited by hand and a release that spelled a case differently, and in both cases
    /// what the reader wants is what a first run would have given them.
    public func appearance() -> AppAppearance {
        defaults.string(forKey: Self.appearanceKey).flatMap(AppAppearance.init(rawValue:)) ?? .default
    }

    public func remember(_ appearance: AppAppearance) {
        defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
    }

    /// **A theme this build does not know falls back to the default rather than to plain text.** It is
    /// the one case here that is reachable without a hand-edited file: a reader on a newer build
    /// chooses a sixth pair, restores that backup onto an older one, and the older build has no
    /// stylesheet for the name it reads. Xcode's colours are what it shipped with, so that is what it
    /// goes back to.
    public func codeTheme() -> CodeTheme {
        defaults.string(forKey: Self.codeThemeKey).flatMap(CodeTheme.init(rawValue:)) ?? .default
    }

    public func remember(_ theme: CodeTheme) {
        defaults.set(theme.rawValue, forKey: Self.codeThemeKey)
    }

    /// **Absent means off, which is what `bool(forKey:)` already answers**, so there is no default to
    /// state and no migration for the releases that never wrote this key. Unified is what every
    /// reader has been reading in, and a setting that turned itself on for them would be a layout
    /// change nobody asked for on first launch after an update.
    public func isSideBySide() -> Bool {
        defaults.bool(forKey: Self.sideBySideKey)
    }

    public func remember(isSideBySide: Bool) {
        defaults.set(isSideBySide, forKey: Self.sideBySideKey)
    }
}
