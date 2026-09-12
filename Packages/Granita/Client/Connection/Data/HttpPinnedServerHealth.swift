import ClientConnectionDomain
import CoreApiDomain
import CorePairingDomain

public actor HttpPinnedServerHealth: PinnedServerHealthChecking {

    private let transport: @Sendable (SpkiFingerprint) -> any HttpTransport
    private var transports: [SpkiFingerprint: any HttpTransport] = [:]

    public init(logs: ConnectionLogs) {
        transport = { fingerprint in
            UrlSessionHttpTransport(pinnedTo: fingerprint, logs: logs, requestTimeout: .seconds(5))
        }
    }

    init(transport: @escaping @Sendable (SpkiFingerprint) -> any HttpTransport) {
        self.transport = transport
    }

    public func health(at address: ServerAddress, pinnedTo fingerprint: SpkiFingerprint) async throws(ApiFailure) -> HealthResponse {
        let session: any HttpTransport
        if let cached = transports[fingerprint] {
            session = cached
        } else {
            session = transport(fingerprint)
            transports[fingerprint] = session
        }
        return try await HttpServerPairing(macReachableAt: address, transport: session).health()
    }
}
