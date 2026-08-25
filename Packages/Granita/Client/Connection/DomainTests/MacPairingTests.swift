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
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then — the Mac keeps a hash and this is the only copy of the token there is, so an
        // outcome that reported success without writing it down would lock the phone out silently.
        #expect(outcome == .paired(aPairedMac))
        #expect(await scenario.tokens.saved == [aPairedDevice.serverInstanceId: aPairedDevice.token])
    }

    @Test
    func `given a Mac serving another contract when pairing then the code is never spent`() async {
        // given — a code lasts two minutes and works once, so learning about skew after spending it
        // costs the reader a walk back to the Mac for another one.
        let scenario = Scenario(servingApiVersion: Branding.apiVersion - 1)

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

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
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then
        #expect(outcome == .refused(.pairingExpired))
    }

    @Test
    func `given five failures in a minute when pairing again then the wait is what is reported`() async {
        // given
        let scenario = Scenario(pairing: .failure(.rateLimited))

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

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
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then
        #expect(outcome == .tokenNotStored(aPairedMac, .refused(status: -34018)))
    }

    // MARK: - What gets pinned, and which path knew it in advance

    @Test
    func `given a scanned link when pairing then what is pinned is the key the link carried`() async {
        // given — the QR travelled over a channel nobody on the network can write to, so the
        // fingerprint was known before a single byte was sent.
        let scenario = Scenario()

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then
        #expect(outcome == .paired(aPairedMac))
        #expect(aPairedMac.fingerprint == aLink.fingerprint)
    }

    @Test
    func `given six words when pairing then what is pinned is the key first contact found`() async {
        // given — the words carry a code and nothing else, so there is no pin to check against and
        // whoever answers becomes the Mac. That is trust on first use, and the point of asserting it
        // here is that the fingerprint is **read back from the handshake** rather than invented: an
        // implementation that made one up would pin a Mac it never spoke to.
        let scenario = Scenario(presenting: anObservedKey)

        // when
        let outcome = await scenario.sut.pair(with: .spoken(code: sixWords, at: anAddress), on: theMacTheReaderOpened, as: anIphone)

        // then
        #expect(
            outcome == .paired(
                PairedMac(
                    name: theMacTheReaderOpened.name,
                    device: aPairedDevice,
                    address: anAddress,
                    fingerprint: anObservedKey
                )
            )
        )
        #expect(await scenario.server.codesOffered == [sixWords])
    }

    @Test
    func `given a Mac that presented no key when pairing then it is not reported as paired`() async {
        // given — not reachable through a real transport, since a handshake happened by definition
        // if a code was spent. It is expressible, though, and the alternative to answering it is a
        // force-unwrap on the one value the whole of this app's transport security rests on.
        let scenario = Scenario(presenting: nil)

        // when
        let outcome = await scenario.sut.pair(with: .spoken(code: sixWords, at: anAddress), on: theMacTheReaderOpened, as: anIphone)

        // then
        #expect(outcome == .refused(.notUnderstood(diagnostic: "the Mac was reached without presenting a key")))
    }

    // MARK: - What the reader calls the Mac, which travels with the pairing

    @Test
    func `given a Mac the reader opened when pairing then the pairing carries the name they saw`() async {
        // given — design §5 titles the worktree list with the Mac's name, and the address is not it:
        // a pairing reached over `192.168.1.24` would put an IP address at the top of the one screen
        // this product exists for.
        let scenario = Scenario()

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then — the browse's own string, not the link's host, so what titles the list is what the
        // reader tapped in the Mac list one screen earlier.
        #expect(outcome == .paired(aPairedMac))
        #expect(aPairedMac.name == "Davide's MacBook Pro")
        #expect(aPairedMac.name != aLink.host)
    }

    // MARK: - The write that failed and can be tried again

    @Test
    func `given the Keychain refused when the write is retried then the token is written down`() async {
        // given — `errSecInteractionNotAllowed` is transient far more often than not, so the phone
        // keeps the pairing rather than sending the reader to another machine to repair something
        // this one can repair itself.
        let scenario = Scenario(keychainRefusing: .refused(status: -25308))
        let refused = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)
        guard case .tokenNotStored(let pairing, _) = refused else {
            Issue.record("a refused Keychain has to hand the pairing back, or there is nothing to retry")
            return
        }
        await scenario.tokens.recover()

        // when
        let outcome = await scenario.sut.saveToken(of: pairing)

        // then — and no second code is spent, because the one that bought this token is gone.
        #expect(outcome == .paired(aPairedMac))
        #expect(await scenario.tokens.saved == [aPairedDevice.serverInstanceId: aPairedDevice.token])
        #expect(await scenario.server.codesOffered == [aLink.code])
    }

    @Test
    func `given a Keychain that still refuses when the write is retried then it says so again`() async {
        // given
        let scenario = Scenario(keychainRefusing: .refused(status: -25308))

        // when
        let outcome = await scenario.sut.saveToken(of: aPairedMac)

        // then — the same outcome carrying the same pairing, so the screen can be tried a third
        // time rather than becoming a dead end after one attempt.
        #expect(outcome == .tokenNotStored(aPairedMac, .refused(status: -25308)))
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
        presenting key: SpkiFingerprint? = aLink.fingerprint,
        holdingTokens held: [ServerInstanceId: PairingToken] = [:],
        keychainRefusing refusal: PairingTokenStoreFailure? = nil
    ) {
        tokens = refusal.map(FakePairingTokenStore.init(refusing:)) ?? FakePairingTokenStore(holding: held)
        server = FakeServerPairing(
            answeringHealth: .success(
                HealthResponse(name: "Granita", apiVersion: apiVersion, serverVersion: "0.0.9")
            ),
            answeringPairing: pairing,
            presenting: key
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

private let anAddress = ServerAddress(host: "davides-macbook-pro.local", port: 59144)

/// The row in the Mac list that was tapped. Its name is deliberately not the link's host: those are
/// two different strings for one machine, and only one of them is what a reader recognises.
private let theMacTheReaderOpened = DiscoveredServer(
    id: "Davide's MacBook Pro._granita._tcp.local.",
    name: "Davide's MacBook Pro"
)

/// What the scanned path ends up holding: the pin arrived with the link.
private let aPairedMac = PairedMac(
    name: theMacTheReaderOpened.name,
    device: aPairedDevice,
    address: anAddress,
    fingerprint: aLink.fingerprint
)

/// A key nothing told the phone about in advance, which is the whole of the spoken path.
private let anObservedKey = SpkiFingerprint(rawValue: "9f86d081884c7d659a2feaa0c55ad015")

private let sixWords = "cabin-cactus-camera-candle-harbour-lantern"
