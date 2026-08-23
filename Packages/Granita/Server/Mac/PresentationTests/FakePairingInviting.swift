import Foundation

import CorePairingDomain
import ServerApiDomain

/// Hands out whatever pairing the test asked for, and counts how many were asked for.
///
/// The count is what a test uses to tell *New Code* apart from a redraw: both leave a live code on
/// screen, and only one of them spent a second one.
final class FakePairingInviting: PairingInviting, @unchecked Sendable {

    /// Safe because every test that touches this drives the model from the main actor and reads the
    /// count afterwards, so no two accesses are concurrent. A lock here would be ceremony around a
    /// counter nothing races for.
    private(set) var invitations = 0
    private(set) var lastEndpoint: ServerEndpoint?

    private let failure: PairingInvitationError?
    private let expiresAt: Date

    init(failure: PairingInvitationError? = nil, expiresAt: Date = Date(timeIntervalSince1970: 120)) {
        self.failure = failure
        self.expiresAt = expiresAt
    }

    func invite(at endpoint: ServerEndpoint) async throws(PairingInvitationError) -> PairingInvitation {
        invitations += 1
        lastEndpoint = endpoint
        if let failure {
            throw failure
        }
        return PairingInvitation(
            link: PairingLink(
                host: endpoint.host,
                port: endpoint.port,
                code: "code-\(invitations)",
                fingerprint: SpkiFingerprint(rawValue: "fingerprint-\(invitations)")
            ),
            spokenCode: "delta-pepper-amber-kelp-jasper-meadow",
            expiresAt: expiresAt
        )
    }
}
