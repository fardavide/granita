import Testing

import ClientConnectionDomain
import CoreApiDomain
import CoreBrandingDomain
import CorePairingDomain

@testable import ClientConnectionPresentation

/// One model for the unit: the browse and the handshake are two views onto the same question, which
/// is which Mac this phone is talking to.
@Suite("Client connection model")
struct ClientConnectionModelTests {

    // MARK: - Finding a Mac

    @Test
    func `given nothing has happened when created then nothing is claimed about either half`() {
        // given - when
        let scenario = Scenario(discovering: [])

        // then
        #expect(scenario.sut.discovery == .idle)
        #expect(scenario.sut.pairing == .notStarted)
    }

    @Test
    func `given a server is nearby when searching then it is offered`() async {
        // given
        let mac = DiscoveredServer(id: "Davide's MacBook Pro", name: "Davide's MacBook Pro")
        let scenario = Scenario(discovering: [.searching, .found([mac])])

        // when
        await scenario.sut.start()

        // then
        #expect(scenario.sut.discovery == .found([mac]))
    }

    @Test
    func `given permission is refused when searching then that is reported as its own state`() async {
        // given — a denial is not a failure the user can only stare at: it is the one they can fix.
        let scenario = Scenario(discovering: [.searching, .localNetworkDenied])

        // when
        await scenario.sut.start()

        // then
        #expect(scenario.sut.discovery == .localNetworkDenied)
        #expect(scenario.sut.isPermissionRefused)
    }

    @Test
    func `given nothing was found when the reader searches again then it is looking once more`() async {
        // given — the browse went quiet and the Mac was plugged in afterwards. Without this the
        // reader's only recourse is to kill the app.
        let scenario = Scenario(discovering: [.searching, .found([])])
        await scenario.sut.start()

        // when
        scenario.sut.searchAgain()

        // then
        #expect(scenario.sut.discovery == .searching)
    }

    @Test
    func `given a browse is running when the reader searches again then a fresh attempt replaces it`() {
        // given
        let scenario = Scenario(discovering: [])
        let before = scenario.sut.attempt

        // when
        scenario.sut.searchAgain()

        // then — the screen keys its task on this, so changing it is what tears the running browse
        // down and puts a new one in its place. Asking the old stream to start over would not make a
        // new browser, and a new browser is the whole mechanism.
        #expect(scenario.sut.attempt != before)
    }

    @Test
    func `given a server disappears when searching then the list empties without erroring`() async {
        // given — a Mac going to sleep is the common case, not an error.
        let mac = DiscoveredServer(id: "MacBook", name: "MacBook")
        let scenario = Scenario(discovering: [.found([mac]), .found([])])

        // when
        await scenario.sut.start()

        // then
        #expect(scenario.sut.discovery == .found([]))
        #expect(scenario.sut.isPermissionRefused == false)
    }

    // MARK: - Joining one

    @Test
    func `given a Mac that agrees when pairing then the token is the only thing kept`() async {
        // given
        let scenario = Scenario(pairing: .success(aPairedDevice))

        // when
        await scenario.sut.pair(using: aLink, as: anIphone)

        // then — the Mac keeps a hash and this is the only copy of the token there is, so a pairing
        // that reported success without writing it down would lock the phone out silently.
        #expect(scenario.sut.pairing == .paired(aPairedDevice.serverInstanceId))
        #expect(await scenario.tokens.saved == [aPairedDevice.serverInstanceId: aPairedDevice.token])
    }

    @Test
    func `given a Mac that agrees when pairing then it joins the Macs this phone knows`() async {
        // given
        let scenario = Scenario(pairing: .success(aPairedDevice))

        // when
        await scenario.sut.pair(using: aLink, as: anIphone)

        // then — what the discovery list's two sections are ordered by.
        #expect(scenario.sut.pairedServers == [aPairedDevice.serverInstanceId])
    }

    @Test
    func `given a Mac serving another contract when pairing then the code is never spent`() async {
        // given — a code lasts two minutes and works once, so learning about skew after spending it
        // costs the reader a walk back to the Mac for another one.
        let scenario = Scenario(
            servingApiVersion: Branding.apiVersion - 1,
            pairing: .success(aPairedDevice)
        )

        // when
        await scenario.sut.pair(using: aLink, as: anIphone)

        // then
        #expect(scenario.sut.pairing == .wrongContract(.macIsBehind(serving: Branding.apiVersion - 1)))
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
        await scenario.sut.pair(using: aLink, as: anIphone)

        // then
        #expect(scenario.sut.pairing == .failed(.pairingExpired))
    }

    @Test
    func `given five failures in a minute when pairing again then the wait is what is reported`() async {
        // given
        let scenario = Scenario(pairing: .failure(.rateLimited))

        // when
        await scenario.sut.pair(using: aLink, as: anIphone)

        // then
        #expect(scenario.sut.pairing == .failed(.rateLimited))
    }

    @Test
    func `given the Keychain refuses when pairing succeeds then that is its own outcome`() async {
        // given — the worst state there is: the Mac now has a device record for a credential this
        // phone does not hold, so the reader has to revoke it there before trying again. Reporting
        // it as an ordinary failure would send them round the same loop forever.
        let scenario = Scenario(
            pairing: .success(aPairedDevice),
            keychainRefusing: .refused(status: -34018)
        )

        // when
        await scenario.sut.pair(using: aLink, as: anIphone)

        // then
        #expect(scenario.sut.pairing == .tokenNotStored(.refused(status: -34018)))
        #expect(scenario.sut.pairedServers.isEmpty)
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
        await scenario.sut.loadPairingHistory()

        // then
        #expect(scenario.sut.pairedServers == [
            ServerInstanceId(rawValue: "3B9AC0DE-1111-4A2C-8D6E-55E0B1CAFE22"),
            ServerInstanceId(rawValue: "77DDEE00-2222-4B3F-91A0-C4D5E6F70088")
        ])
    }

    @Test
    func `given a Keychain that will not enumerate when the history is read then the list still shows`() async {
        // given — the history only orders the list. Refusing to show the Macs that are actually on
        // the network because a sort key is unavailable is the worse screen.
        let scenario = Scenario(keychainRefusing: .unreadable)

        // when
        await scenario.sut.loadPairingHistory()

        // then
        #expect(scenario.sut.pairedServers.isEmpty)
    }
}

// MARK: -

private struct Scenario {

    let sut: ClientConnectionModel
    let tokens: FakePairingTokenStore
    let server: FakeServerPairing

    init(
        discovering states: [DiscoveryState] = [],
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
        sut = ClientConnectionModel(
            browsing: FakeServerDiscovery(states: states),
            tokens: tokens,
            handshake: { _ in mac }
        )
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
