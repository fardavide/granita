import Foundation

import CorePairingDomain
import ServerApiDomain
import ServerIdentityDomain

/// Everything a phone needs to pair, gathered from the three places it lives.
///
/// The identity was generated on first run, the endpoint was settled when the system chose a port,
/// and the code was made a moment ago. Putting them together is small enough to look like it
/// belongs at a call site — and it is exactly the assembly that must not be got wrong, because a
/// link naming a key this Mac does not serve under pairs a phone that then refuses every
/// connection afterwards, with nothing on either side saying why.
public struct PairingInvitations: PairingInviting {

    private let pairing: Pairing
    private let identities: any ServerIdentityStore

    public init(pairing: Pairing, identities: any ServerIdentityStore) {
        self.pairing = pairing
        self.identities = identities
    }

    public func invite(at endpoint: ServerEndpoint) async throws(PairingInvitationError) -> PairingInvitation {
        // Asked for first, and allowed to fail the whole thing. A link with no fingerprint would
        // pair a phone that afterwards trusts whatever answers on that address.
        let identity: ServerIdentity
        do {
            identity = try await identities.identity()
        } catch {
            throw .noIdentity(reason: error.explanation)
        }
        let code = await pairing.invite()

        return PairingInvitation(
            link: PairingLink(
                host: endpoint.host,
                port: endpoint.port,
                code: code.code,
                fingerprint: identity.fingerprint
            ),
            spokenCode: code.spokenCode,
            expiresAt: code.expiresAt
        )
    }
}
