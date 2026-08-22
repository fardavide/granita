/// Whether Granita opens itself when the Mac starts, as the General tab draws it.
///
/// Three cases rather than a boolean and a message beside it, because "off" and "off because macOS
/// said no" are what a reader has to tell apart, and a pair of properties can hold the combination
/// that means neither.
public enum LoginItemState: Hashable, Sendable {

    case off

    case on

    /// Registered, and macOS will not act on it until someone approves Granita in Login Items.
    ///
    /// This is the **ordinary** outcome of turning the toggle on for the first time, not an error,
    /// and it is the case most easily mistaken for success: `SMAppService.register()` returns
    /// without throwing and the item still does not run at the next login.
    case awaitingApproval

    /// Asked to register and refused, carrying the system's own words.
    case refused(reason: String)
}

/// Why a registration did not take.
///
/// The toggle reads **off** for both of these, never on: an app that will not start with the Mac is
/// something a person finds out at the worst possible moment, and a toggle left on for a
/// registration that will not happen is the only reading on this tab that is actively false.
public enum LoginItemFailure: Error, Hashable, Sendable {

    /// The registration was accepted and is waiting on approval in Login Items.
    case notApproved

    /// macOS declined outright, and this is what it said. Kept verbatim: the two reasons this
    /// happens in practice — Login Items managed by a configuration profile, and an app
    /// registering from a location it will not be at next launch — are told apart by nothing else.
    case refused(reason: String)
}

/// The login item, behind a protocol like every other edge that leaves this process.
///
/// Registration is a system-wide fact rather than a preference this app keeps, which is why there
/// is a read here at all: System Settings can turn Granita's login item off while Granita is not
/// running, and a value remembered from last launch would be a toggle disagreeing with the system
/// it claims to report.
public protocol LoginItemRegistry: Sendable {

    func isRegistered() async -> Bool

    func register() async throws(LoginItemFailure)

    func unregister() async throws(LoginItemFailure)
}
