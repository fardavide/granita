import Foundation

import ClientWorktreesDomain

/// How the sidebar was left, in this phone's user defaults.
///
/// Defaults rather than anything the Mac holds: this is a fact about how one reader likes their own
/// list arranged, and the Mac does not have an opinion about it. It is also the one thing here that
/// may be lost without consequence — a reader who restores to a new phone lands on the arrangement a
/// first run gives.
// `UserDefaults` is documented as thread-safe and carries no `Sendable` conformance, so the
// invariant the compiler cannot see is upheld by the class itself rather than by anything here.
public struct UserDefaultsWorktreeListPreferences: WorktreeListPreferences, @unchecked Sendable {

    /// Exposed because they are a storage contract rather than an implementation detail: a test
    /// asserting what happens to a value no release ever wrote has to be able to write one.
    public static let modeKey = "granita.worktrees.mode"
    public static let showsQuietKey = "granita.worktrees.showsQuiet"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// A word that names no mode falls back rather than failing. It can only come from a defaults
    /// file edited by hand or written by a release that spelled a mode differently, and in both
    /// cases what a reader wants is the list they would have got on a first run.
    public func mode() -> WorktreeListMode {
        defaults.string(forKey: Self.modeKey).flatMap(WorktreeListMode.init(rawValue:)) ?? .groupedByProject
    }

    public func remember(_ mode: WorktreeListMode) {
        defaults.set(mode.rawValue, forKey: Self.modeKey)
    }

    /// Hidden is the default, and the list says how many it hid — which is what keeps this number
    /// and the Mac's from silently contradicting each other.
    public func showsQuietWorktrees() -> Bool {
        defaults.bool(forKey: Self.showsQuietKey)
    }

    public func rememberShowingQuietWorktrees(_ shows: Bool) {
        defaults.set(shows, forKey: Self.showsQuietKey)
    }
}
