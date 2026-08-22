import Foundation

/// What the Mac calls this phone once it has let it in.
public struct DeviceId: RawRepresentable, Hashable, Sendable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Which Mac this is, across restarts and across a changed address.
///
/// The phone stores its token against this rather than against a host name, because a Bonjour
/// service takes whatever port the system gives it and the name of a Mac is a thing people rename.
public struct ServerInstanceId: RawRepresentable, Hashable, Sendable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// The bearer credential for one Mac.
///
/// **The phone holds the only copy.** The Mac keeps a hash, so this cannot be recovered from it and
/// losing it means pairing again. Typed rather than a `String` for the ordinary reason every
/// identifier here is — but with more at stake, since a token passed where a device identifier was
/// expected would put a credential somewhere a credential does not belong.
public struct PairingToken: RawRepresentable, Hashable, Sendable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// How a phone introduces itself when it asks to pair.
///
/// A value rather than two adjacent `String` parameters: the Mac renders both of these in its
/// Devices tab, and a swapped pair would read as a device called "iOS" on a platform called
/// "Davide's iPhone" with nothing to catch it.
public struct PairingDevice: Hashable, Sendable {

    public let name: String
    public let platform: String

    public init(name: String, platform: String) {
        self.name = name
        self.platform = platform
    }
}

/// A pairing that succeeded, as the phone records it.
public struct PairedDevice: Hashable, Sendable {

    public let token: PairingToken
    public let deviceId: DeviceId
    public let serverInstanceId: ServerInstanceId

    public init(token: PairingToken, deviceId: DeviceId, serverInstanceId: ServerInstanceId) {
        self.token = token
        self.deviceId = deviceId
        self.serverInstanceId = serverInstanceId
    }
}
