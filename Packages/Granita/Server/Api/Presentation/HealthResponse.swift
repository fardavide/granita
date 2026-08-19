import CoreBrandingDomain

/// The body of `/v1/health`, and the first thing a phone ever reads from a Mac.
///
/// It answers before pairing, so it is what tells "wrong address" apart from "wrong version" apart
/// from "not authorised". The Mac app and the TestFlight phone app ship independently, so version
/// skew is guaranteed rather than unlikely: the client refuses to pair on an `apiVersion` mismatch
/// instead of decoding a payload it half-understands.
public struct HealthResponse: Codable, Hashable, Sendable {

    public let name: String
    public let apiVersion: Int
    public let serverVersion: String

    public init(name: String, apiVersion: Int, serverVersion: String) {
        self.name = name
        self.apiVersion = apiVersion
        self.serverVersion = serverVersion
    }

    /// The values a running server reports. `serverVersion` is the only one that is not a constant,
    /// which is why it is the only parameter.
    public init(serverVersion: String) {
        self.init(
            name: Branding.productName,
            apiVersion: Branding.apiVersion,
            serverVersion: serverVersion
        )
    }
}
