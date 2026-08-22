import Testing

import CoreApiDomain
import CoreBrandingDomain
import CorePairingDomain

@testable import ClientConnectionDomain

/// Joining a Mac is three steps that only make sense in one order, so the order is what most of
/// these assert.
@Suite("Mac pairing")
struct MacPairingTests {

    @Test
    func `given a Mac that agrees when pairing then the token is written down`() async {
        // given
        let scenario = Scenario()

        // when
        let outcome = await scenario.sut.pair(with: aLink, as: anIphone)

        // then — the Mac keeps a hash and this is the only copy of the token there is, so an
        // outcome that reported success without writing it down would lock the phone out silently.
        #expect(outcome == .paired(aPairedDevice))
        #expect(await scenario.tokens.saved == [aPairedDevice.serverInstanceId: aPairedDevice.token])
    }

    @Test
    func `given a Mac serving another contract when pairing then the code is never spent`() async {
        // given — a code lasts two minutes and works once, so learning about skew after spending it
        // costs the reader a walk back to the Mac for another one.
        let scenario = Scenario(servingApiVersion: Branding.apiVersion - 1)

        // when
        let outcome = await scenario.sut.pair(with: aLink, as: anIphone)

        // then
        #expect(outcome == .wrongContract(.macIsBehind(serving: Branding.apiVersion - 1)))
        #expect(await scenario.server.codesOffered.isEmpty)
        #expect(await scenario.tokens.saved.isEmpty)
    }

    @Test
    func `given a code the Mac refused when pairing then the phone does not guess why`() async {
        // given — the Mac answers the same way whether the code never existed or merely ran out, on
        // purpose. Inventing the distinction back on this side would put a sentence on screen that
        // the Mac deliberately declined to say.
        let scenario = Scenario(pairing: .failure(.pairingExpired))

        // when
        let outcome = await scenario.sut.pair(with: aLink, as: anIphone)

        // then
        #expect(outcome == .refused(.pairingExpired))
    }

    @Test
    func `given five failures in a minute when pairing again then the wait is what is reported`() async {
        // given
        let scenario = Scenario(pairing: .failure(.rateLimited))

        // when
        let outcome = await scenario.sut.pair(with: aLink, as: anIphone)

        // then
        #expect(outcome == .refused(.rateLimited))
    }

    @Test
    func `given the Keychain refuses when pairing succeeds then that is its own outcome`() async {
        // given — the worst state there is: the Mac now holds a device record for a credential this
        // phone does not have, so the reader has to revoke it there before trying again. Reporting
        // it as an ordinary refusal would send them round the same loop forever.
        let scenario = Scenario(keychainRefusing: .refused(status: -34018))

        // when
        let outcome = await scenario.sut.pair(with: aLink, as: anIphone)

        // then
        #expect(outcome == .tokenNotStored(.refused(status: -34018)))
    }

    @Test
    func `given tokens for two Macs when the history is read then both are known`() async {
        // given
        let scenario = Scenario(holdingTokens: [
            ServerInstanceId(rawValue: "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22"):
                PairingToken(rawValue: "1f0e4d7c6b5a4938"),
            ServerInstanceId(rawValue: "77DDEE00-2222-4B3F-91A0-C4D5E6F70088"):
                PairingToken(rawValue: "2a3b4c5d6e7f8091")
        ])

        // when
        let known = await scenario.sut.alreadyPaired()

        // then
        #expect(known == [
            ServerInstanceId(rawValue: "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22"),
            ServerInstanceId(rawValue: "77DDEE00-2222-4B3F-91A0-C4D5E6F70088")
        ])
    }

    @Test
    func `given a Keychain that will not enumerate when the history is read then nothing is claimed`() async {
        // given — the history only orders a list. Refusing to show the Macs that are actually on the
        // network because a sort key is unavailable is the worse screen.
        let scenario = Scenario(keychainRefusing: .unreadable)

        // when
        let known = await scenario.sut.alreadyPaired()

        // then
        #expect(known.isEmpty)
    }
}

// MARK: -

private struct Scenario {

    let sut: MacPairing
    let tokens: FakePairingTokenStore
    let server: FakeServerPairing

    init(
        servingApiVersion apiVersion: Int = Branding.apiVersion,
        pairing: Result<PairedDevice, ApiFailure> = .success(aPairedDevice),
        holdingTokens held: [ServerInstanceId: PairingToken] = [:],
        keychainRefusing refusal: PairingTokenStoreFailure? = nil
    ) {
        tokens = refusal.map(FakePairingTokenStore.init(refusing:)) ?? FakePairingTokenStore(holding: held)
        server = FakeServerPairing(
            answeringHealth: .success(
                HealthResponse(name: "Granita", apiVersion: apiVersion, serverVersion: "0.0.9")
            ),
            answeringPairing: pairing
        )
        let mac = server
        sut = MacPairing(tokens: tokens, handshake: { _ in mac })
    }
}

private let aPairedDevice = PairedDevice(
    token: PairingToken(rawValue: "1f0e4d7c6b5a49382736251403f2e1d0"),
    deviceId: DeviceId(rawValue: "8C4F2A11-0000-4E5D-9A3B-77F1C0DE0001"),
    serverInstanceId: ServerInstanceId(rawValue: "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22")
)

private let aLink = PairingLink(
    host: "davides-macbook-pro.local",
    port: 59144,
    code: "9d41e0c7a2b85f36",
    fingerprint: SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007")
)

private let anIphone = PairingDevice(name: "Davide's iPhone", platform: "iOS")
