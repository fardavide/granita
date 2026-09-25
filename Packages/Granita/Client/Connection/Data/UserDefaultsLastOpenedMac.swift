import Foundation

import ClientConnectionDomain

/// Which Mac this phone opened last, in its user defaults.
///
/// Defaults rather than the Keychain beside the pairing, because the two answer different questions:
/// the Keychain says which Macs may be opened at all, and this says which of them to open first. It
/// is also the one that may be lost without consequence — a reader who restores onto a new phone
/// lands on the Mac list, which is where every release before this one started.
// `UserDefaults` is documented as thread-safe and carries no `Sendable` conformance, so the
// invariant the compiler cannot see is upheld by the class itself rather than by anything here.
public struct UserDefaultsLastOpenedMac: LastOpenedMacPreference, @unchecked Sendable {

    /// Exposed because they are a storage contract rather than an implementation detail: a test
    /// asserting what happens to a value no release ever wrote has to be able to write one.
    public static let instanceKey = "granita.macs.lastOpened.instance"
    public static let nameKey = "granita.macs.lastOpened.name"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// **Both halves or neither.** One is the identity a session is opened against and the other is
    /// what the screen is titled with, so half a record resumes onto a worktree list with no name on
    /// it — and a defaults file can hold half, having been written by a release that spelled the
    /// other key differently.
    public func lastOpenedMac() -> DiscoveredServer? {
        guard let instance = defaults.string(forKey: Self.instanceKey),
              let name = defaults.string(forKey: Self.nameKey) else {
            return nil
        }
        return DiscoveredServer(id: BonjourInstanceName(rawValue: instance), name: name)
    }

    public func remember(_ mac: DiscoveredServer) {
        defaults.set(mac.id.rawValue, forKey: Self.instanceKey)
        defaults.set(mac.name, forKey: Self.nameKey)
    }

    public func forget() {
        defaults.removeObject(forKey: Self.instanceKey)
        defaults.removeObject(forKey: Self.nameKey)
    }
}
