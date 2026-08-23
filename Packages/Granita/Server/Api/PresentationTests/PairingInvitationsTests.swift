import Foundation
import Testing

import CorePairingDomain
import ServerApiDomain
import ServerApiPresentation
import ServerIdentityDomain

/// What a phone is actually shown: a link for its camera, and six words for when it has none.
///
/// The three things in it exist at three different times — the identity was generated on first
/// run, the endpoint was settled when the system chose a port, and the code was made a second ago —
/// which is the whole reason there is a type that puts them together rather than a call site that
/// remembers to.
struct PairingInvitationsTests {

    @Test func `when an invitation is made then its link points at the endpoint the server is on`() async throws {
        // given
        let scenario = try Scenario()

        // when
        let invitation = try await scenario.invitations.invite(at: ServerEndpoint(host: "macbook.local", port: 51234))

        // then
        #expect(invitation.link.host == "macbook.local")
        #expect(invitation.link.port == 51234)
    }

    @Test func `when an invitation is made then its link carries the fingerprint of the certificate served`() async throws {
        // given
        let scenario = try Scenario()

        // when
        let invitation = try await scenario.invitations.invite(at: ServerEndpoint(host: "macbook.local", port: 51234))

        // then
        // The one field that cannot be wrong. A link naming a key this Mac does not serve under is
        // a phone that pairs once and then refuses every connection afterwards, with nothing on
        // either side saying why.
        #expect(invitation.link.fingerprint == scenario.identities.certificate.fingerprint)
    }

    @Test func `when an invitation is made then its link carries a code the server will accept`() async throws {
        // given
        let scenario = try Scenario()

        // when
        let invitation = try await scenario.invitations.invite(at: ServerEndpoint(host: "macbook.local", port: 51234))

        // then
        _ = try await scenario.pairing.redeem(
            code: invitation.link.code,
            deviceName: "Davide's iPhone",
            platform: "iOS"
        )
        #expect(await scenario.store.state().devices.count == 1)
    }

    @Test func `when an invitation is made then the words under the link redeem the same pairing`() async throws {
        // given
        let scenario = try Scenario()

        // when
        let invitation = try await scenario.invitations.invite(at: ServerEndpoint(host: "macbook.local", port: 51234))

        // then
        _ = try await scenario.pairing.redeem(
            code: invitation.spokenCode,
            deviceName: "Davide's iPad",
            platform: "iPadOS"
        )
        await #expect(throws: PairingRefusal.noSuchCode) {
            try await scenario.pairing.redeem(
                code: invitation.link.code,
                deviceName: "somebody else",
                platform: "iOS"
            )
        }
    }

    @Test func `given a keychain that will not answer when an invitation is asked for then it is refused`() async throws {
        // given
        let scenario = try Scenario(
            identityFailure: .keychainRefused(operation: "looking for the existing certificate", status: -25308)
        )

        // when - then
        // No fingerprint means no link worth showing: a QR without one pairs a phone that then
        // trusts whatever answers. Refused rather than shown incomplete — and refused in words,
        // because the Devices tab prints this under its own sentence and the only person who can
        // act on it is standing at the Mac.
        await #expect(
            throws: PairingInvitationError.noIdentity(
                reason: "the Keychain refused while looking for the existing certificate (-25308) — unlock the login keychain"
            )
        ) {
            try await scenario.invitations.invite(at: ServerEndpoint(host: "macbook.local", port: 51234))
        }
    }

    // MARK: -

    private struct Scenario {

        let store = FakeStore()
        let identities: FakeServerIdentityStore
        let pairing: Pairing
        let invitations: PairingInvitations

        init(identityFailure: ServerIdentityError? = nil) throws {
            identities = try FakeServerIdentityStore(failure: identityFailure)
            let store = store
            pairing = Pairing(store: store, now: { Date(timeIntervalSince1970: 1_771_632_000) })
            invitations = PairingInvitations(pairing: pairing, identities: identities)
        }
    }
}
