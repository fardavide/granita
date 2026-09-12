import CoreApiDomain
import CorePairingDomain

public protocol PinnedServerHealthChecking: Sendable {
    func health(at address: ServerAddress, pinnedTo fingerprint: SpkiFingerprint) async throws(ApiFailure) -> HealthResponse
}
