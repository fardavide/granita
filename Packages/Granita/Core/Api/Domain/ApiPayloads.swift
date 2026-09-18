import CoreReviewDomain

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

/// What `/v1/worktrees/…/review` carries, in both directions.
///
/// The whole review rather than one comment: it is small, whoever is sending holds all of it, and a
/// per-comment route would make clearing it a sequence of requests with a half-cleared review on the
/// Mac in the middle of it.
public struct ReviewRequest: Codable, Hashable, Sendable {

    public let comments: [ReviewComment]

    public init(comments: [ReviewComment]) {
        self.comments = comments
    }
}

/// What `/v1/review-settings` answers with.
///
/// `openingLine` absent means the reader has never chosen one and the built-in line is used; present
/// and empty means they chose to have none, and the document begins at its first comment. Those are
/// different answers and the wire keeps them apart.
public struct ReviewSettingsResponse: Codable, Hashable, Sendable {

    public let openingLine: String?
    public let identifier: ReviewIdentifier

    public init(openingLine: String?, identifier: ReviewIdentifier) {
        self.openingLine = openingLine
        self.identifier = identifier
    }
}

/// What `PATCH /v1/review-settings` is told, carrying only what the reader changed.
///
/// **Presence versus null, the same idiom the worktree patch already uses**, and here it is what
/// makes an edit made while the Mac was away safe: a queued opening line must not carry a label
/// style this phone never read. A key that is absent leaves that setting alone; a key present and
/// null clears it; a key with a value sets it.
public struct ReviewSettingsPatchRequest: Codable, Hashable, Sendable {

    /// Outer nil is "not mentioned"; inner nil is "cleared".
    public let openingLine: String??
    public let identifier: ReviewIdentifier?

    public init(openingLine: String??, identifier: ReviewIdentifier?) {
        self.openingLine = openingLine
        self.identifier = identifier
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // `decodeIfPresent` answers nil for an absent key and for an explicit null alike, and those
        // are the two cases this type exists to tell apart — so the key is asked for by name first.
        openingLine = container.contains(.openingLine)
            ? .some(try container.decodeIfPresent(String.self, forKey: .openingLine))
            : nil
        identifier = try container.decodeIfPresent(ReviewIdentifier.self, forKey: .identifier)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let openingLine {
            // Encoded even when it is nil, because null is the instruction to clear it.
            try container.encode(openingLine, forKey: .openingLine)
        }
        try container.encodeIfPresent(identifier, forKey: .identifier)
    }

    private enum CodingKeys: String, CodingKey {
        case openingLine
        case identifier
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
