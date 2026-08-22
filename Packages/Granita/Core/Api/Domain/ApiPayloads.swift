/// What `/v1/pair` is asked.
///
/// The phone writes it and the Mac reads it, so there is one definition rather than one per side:
/// a key spelled `device` on one end and `deviceName` on the other is a pairing that fails with
/// nothing to read.
public struct PairRequest: Codable, Hashable, Sendable {

    /// Either the code the QR carried or the six words typed instead of it. The Mac accepts both
    /// for one pairing and spending either spends both.
    public let code: String

    public let deviceName: String
    public let platform: String

    public init(code: String, deviceName: String, platform: String) {
        self.code = code
        self.deviceName = deviceName
        self.platform = platform
    }
}

/// What `/v1/worktrees/…/viewed` is told.
///
/// The hash is not decoration and is not optional: a mark applied to a version nobody read is the
/// one way this feature can actively mislead someone, so the Mac refuses a stale one rather than
/// applying it.
public struct ViewedRequest: Codable, Hashable, Sendable {

    public let viewed: Bool
    public let contentHash: String

    public init(viewed: Bool, contentHash: String) {
        self.viewed = viewed
        self.contentHash = contentHash
    }
}

/// What `/v1/pair` answers with.
///
/// The token is returned exactly once and stored hashed on the Mac, so a store that leaks leaks
/// nothing usable — and the phone's copy is the only one there is.
public struct PairResponse: Codable, Hashable, Sendable {

    public let token: String
    public let deviceId: String
    public let serverInstanceId: String

    public init(token: String, deviceId: String, serverInstanceId: String) {
        self.token = token
        self.deviceId = deviceId
        self.serverInstanceId = serverInstanceId
    }
}
