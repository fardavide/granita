import Testing

import ClientConnectionDomain
import CoreApiDomain
import CoreBrandingDomain
import CorePairingDomain

@testable import ClientConnectionPresentation

/// One model for the unit: the browse and the join are two views onto the same question, which is
/// which Mac this phone is talking to. What the sequence *is* belongs to `MacPairing`; what this
/// holds is where it got to.
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
    func `given a Mac that agrees when it is joined then the outcome is what the screen reads`() async {
        // given
        let scenario = Scenario()

        // when
        await scenario.sut.join(aLink, as: anIphone)

        // then
        #expect(scenario.sut.pairing == .finished(.paired(aPairedDevice)))
    }

    @Test
    func `given a Mac that agrees when it is joined then it joins the Macs this phone knows`() async {
        // given
        let scenario = Scenario()

        // when
        await scenario.sut.join(aLink, as: anIphone)

        // then — what the discovery list's two sections will be ordered by, without waiting for the
        // Keychain to be read again.
        #expect(scenario.sut.pairedServers == [aPairedDevice.serverInstanceId])
    }

    @Test
    func `given a Mac that refuses when it is joined then no Mac is recorded as known`() async {
        // given
        let scenario = Scenario(joining: .refused(.pairingExpired))

        // when
        await scenario.sut.join(aLink, as: anIphone)

        // then
        #expect(scenario.sut.pairing == .finished(.refused(.pairingExpired)))
        #expect(scenario.sut.pairedServers.isEmpty)
    }

    @Test
    func `given tokens already in the Keychain when the history is read then the model carries them`() async {
        // given
        let scenario = Scenario(alreadyPaired: [aPairedDevice.serverInstanceId])

        // when
        await scenario.sut.loadPairingHistory()

        // then
        #expect(scenario.sut.pairedServers == [aPairedDevice.serverInstanceId])
    }
}

// MARK: -

private struct Scenario {

    let sut: ClientConnectionModel

    init(
        discovering states: [DiscoveryState] = [],
        joining outcome: PairingOutcome = .paired(aPairedDevice),
        alreadyPaired known: Set<ServerInstanceId> = []
    ) {
        sut = ClientConnectionModel(
            browsing: FakeServerDiscovery(states: states),
            joining: FakeMacJoining(outcome: outcome, known: known)
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
