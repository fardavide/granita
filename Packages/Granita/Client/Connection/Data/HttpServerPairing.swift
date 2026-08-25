import Foundation

import ClientConnectionDomain
import CoreApiDomain
import CorePairingDomain

/// The two routes a phone may reach before it has a token.
///
/// Built against one Mac, over a transport pinned to that Mac's key — so a mixed-up address is a
/// refused handshake rather than a code spent on somebody else's machine.
public struct HttpServerPairing: ServerPairing {

    private let client: GranitaHttpClient

    public init(macAt baseUrl: URL, transport: any HttpTransport) {
        client = GranitaHttpClient(baseUrl: baseUrl, transport: transport, authorization: .unauthenticated)
    }

    /// Built from whichever credential the reader offered.
    ///
    /// Turning a host and a port into an address is this layer's job rather than the composition
    /// root's, for the same reason it always was: it is the only layer that knows the scheme is
    /// `https`, and the only one with a test that can watch where a request actually went.
    public init(mac attempt: PairingAttempt, transport: any HttpTransport) {
        self.init(macAt: attempt.address.httpsUrl ?? URL(filePath: "/nowhere"), transport: transport)
    }

    /// Built from the link the camera read.
    ///
    /// A host that will not go into a URL is a scanned code that is damaged, and the fallback treats
    /// it as one — an address nothing answers on, which surfaces as "could not reach your Mac"
    /// rather than as a crash. That is the same sentence a reader gets from pointing the camera at
    /// the right screen on the wrong network, which is the closest true thing this app can say.
    ///
    /// **It is a fallback rather than a resting place**, and an IPv6 address used to land in it: see
    /// the URL this is built through for what an address has to survive before it earns that
    /// sentence.
    public init(mac link: PairingLink, transport: any HttpTransport) {
        self.init(
            macAt: ServerAddress(host: link.host, port: link.port).httpsUrl ?? URL(filePath: "/nowhere"),
            transport: transport
        )
    }

    /// Asked of the transport rather than remembered here, because on the spoken path the answer
    /// does not exist until a handshake has happened.
    public func trustedFingerprint() async -> SpkiFingerprint? {
        await client.transport.trustedFingerprint()
    }

    public func health() async throws(ApiFailure) -> HealthResponse {
        try await client.get("/v1/health", returning: HealthResponse.self)
    }

    public func pair(with code: String, as device: PairingDevice) async throws(ApiFailure) -> PairedDevice {
        let accepted = try await client.post(
            "/v1/pair",
            body: PairRequest(code: code, deviceName: device.name, platform: device.platform),
            returning: PairResponse.self
        )
        // Three strings on the wire become three types here, at the boundary, because above this
        // line a token and a device identifier must never be interchangeable.
        return PairedDevice(
            token: PairingToken(rawValue: accepted.token),
            deviceId: DeviceId(rawValue: accepted.deviceId),
            serverInstanceId: ServerInstanceId(rawValue: accepted.serverInstanceId)
        )
    }
}
