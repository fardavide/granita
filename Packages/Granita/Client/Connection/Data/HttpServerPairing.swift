import Foundation

import ClientConnectionDomain
import CoreApiDomain

/// The two routes a phone may reach before it has a token.
///
/// Built against one Mac, over a transport pinned to that Mac's key — so a mixed-up address is a
/// refused handshake rather than a code spent on somebody else's machine.
public struct HttpServerPairing: ServerPairing {

    private let client: GranitaHttpClient

    public init(macAt baseUrl: URL, transport: any HttpTransport) {
        client = GranitaHttpClient(baseUrl: baseUrl, transport: transport, authorization: .unauthenticated)
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
