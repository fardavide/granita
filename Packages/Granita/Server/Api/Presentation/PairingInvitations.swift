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
public struct PairingInvitations: Sendable {

    private let pairing: Pairing
    private let identities: any ServerIdentityStore

    public init(pairing: Pairing, identities: any ServerIdentityStore) {
        self.pairing = pairing
        self.identities = identities
    }

    public func invite(at endpoint: ServerEndpoint) async throws(ServerIdentityError) -> PairingInvitation {
        // Asked for first, and allowed to fail the whole thing. A link with no fingerprint would
        // pair a phone that afterwards trusts whatever answers on that address.
        let identity = try await identities.identity()
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

/// A link for the camera, and six words for when there is not one.
public struct PairingInvitation: Hashable, Sendable {

    public let link: PairingLink
    public let spokenCode: String
    public let expiresAt: Date

    public init(link: PairingLink, spokenCode: String, expiresAt: Date) {
        self.link = link
        self.spokenCode = spokenCode
        self.expiresAt = expiresAt
    }
}
