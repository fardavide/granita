import Foundation

import CoreDiagnosticsDomain

/// The verbose switch, in this Mac's user defaults.
///
/// Read on every line rather than cached, which is what lets the switch on Advanced take effect on a
/// server that has been running since launch — `UserDefaults` answers from memory, so this costs
/// nothing worth caching against.
///
/// Off when nothing has been stored, and that is the honest default rather than a cautious one:
/// design §7's footnote says verbose records **every** request and **every** git invocation, which
/// is a volume nobody wants until they are looking for something.
// `UserDefaults` is documented as thread-safe and carries no `Sendable` conformance, so the
// invariant the compiler cannot see is upheld by the class itself rather than by anything here.
public struct UserDefaultsVerboseLogging: VerboseLogging, @unchecked Sendable {

    /// A storage contract rather than an implementation detail: `defaults write` is how this gets
    /// turned on until Advanced grows the switch, and a key nobody can spell is not one.
    public static let defaultsKey = "granita.diagnostics.verbose"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var isVerbose: Bool {
        defaults.bool(forKey: Self.defaultsKey)
    }

    public func setVerbose(_ isVerbose: Bool) {
        defaults.set(isVerbose, forKey: Self.defaultsKey)
    }
}
