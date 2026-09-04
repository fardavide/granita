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
        // Filed under the Bonjour instance name, which is the only name for this Mac the phone will
        // have next time it sees one in a browse — and it is the whole pairing rather than the token
        // alone, because a token without the key beside it could not pin the session that spends it.
        #expect(
            await scenario.macs.saved == [
                theMacTheReaderOpened.id: RememberedMac(
                    device: aPairedDevice,
                    fingerprint: aLink.fingerprint,
                    wakeAddresses: []
                )
            ]
        )
    }

    @Test
    func `given a Mac that reports hardware addresses when pairing then they are written down beside the token`() async {
        // given — **the only moment a wake address ever enters this phone.** Nothing else writes a
        // pairing, so if this line stops working no Mac is ever wakeable and no other test notices.
        let scenario = Scenario(servingWakeAddresses: ["3e:2d:c6:c3:4b:fe", "a4:83:e7:11:22:33"])

        // when
        _ = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then
        #expect(
            await scenario.macs.saved[theMacTheReaderOpened.id]?.wakeAddresses.map(\.text)
                == ["3e:2d:c6:c3:4b:fe", "a4:83:e7:11:22:33"]
        )
    }

    @Test
    func `given a Mac reporting one address that is not one when pairing then it is dropped and the pairing stands`() async {
        // given — a Mac of some other version, or a corrupted answer. One bad entry must cost that
        // entry rather than the pairing, which would send the reader back for another code.
        let scenario = Scenario(servingWakeAddresses: ["nonsense", "3e:2d:c6:c3:4b:fe"])

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then
        #expect(outcome == .paired(aPairedMac(wakingAt: ["3e:2d:c6:c3:4b:fe"])))
        #expect(
            await scenario.macs.saved[theMacTheReaderOpened.id]?.wakeAddresses.map(\.text)
                == ["3e:2d:c6:c3:4b:fe"]
        )
    }

    @Test
    func `given a Mac too old to report a hardware address when pairing then it is remembered and simply not wakeable`() async {
        // given — every Mac running a version from before health carried this.
        let scenario = Scenario(servingWakeAddresses: nil)

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then — paired, which is the point: an absent field is an ordinary answer and not a refusal.
        #expect(outcome == .paired(aPairedMac))
        #expect(await scenario.macs.saved[theMacTheReaderOpened.id]?.wakeAddresses.isEmpty == true)
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
        #expect(await scenario.macs.saved.isEmpty)
    }

    @Test
    func `given a Mac that will not answer the contract read when pairing then nothing is spent`() async {
        // given — the read route is first precisely so that a Mac which cannot be reached costs the
        // reader nothing: a code is single use, and one spent against a machine that never answered
        // is a walk back to the other room for another one.
        let scenario = Scenario(refusingHealth: .unreachable(diagnostic: "Could not connect to the server."))

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then — the Mac's own words survive rather than becoming a sentence of ours, which is what
        // the outcome screen prints in small print under one.
        #expect(outcome == .refused(.unreachable(diagnostic: "Could not connect to the server.")))
        #expect(await scenario.server.codesOffered.isEmpty)
        #expect(await scenario.macs.saved.isEmpty)
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
                    instance: theMacTheReaderOpened.id,
                    name: theMacTheReaderOpened.name,
                    device: aPairedDevice,
                    address: anAddress,
                    fingerprint: anObservedKey,
                    wakeAddresses: []
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
        // reader tapped in the Mac list one screen earlier. Read off the outcome rather than off
        // the fixture: the two are compared above, and an assertion against a constant this file
        // wrote is a sentence about this file.
        guard case .paired(let pairing) = outcome else {
            Issue.record("a Mac that agrees has to come back paired, or there is no name to check")
            return
        }
        #expect(outcome == .paired(aPairedMac))
        #expect(pairing.name == "Davide's MacBook Pro")
        #expect(pairing.name != aLink.host)
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
        await scenario.macs.recover()

        // when
        let outcome = await scenario.sut.saveToken(of: pairing)

        // then — and no second code is spent, because the one that bought this token is gone.
        #expect(outcome == .paired(aPairedMac))
        #expect(
            await scenario.macs.saved == [
                theMacTheReaderOpened.id: RememberedMac(
                    device: aPairedDevice,
                    fingerprint: aLink.fingerprint,
                    wakeAddresses: []
                )
            ]
        )
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

    // MARK: - The step that never answers

    @Test
    func `given a Mac that never answers the contract read when pairing then it says so and nothing is spent`() async {
        // given — the bound is a backstop rather than a policy: every step below it already has a
        // timeout of its own, and this is what is left when one of them does not honour it.
        let scenario = Scenario(silentOn: .readingTheContract)

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then
        #expect(outcome == .neverAnswered(.readingTheContract))
        #expect(await scenario.server.codesOffered.isEmpty)
    }

    @Test
    func `given a Mac that never answers after the code is sent when pairing then it does not claim the code is unused`() async {
        // given — the dangerous one. The code left the phone, so the Mac may already hold a device
        // record for it, and the sentence the reader gets has to be as careful as the Keychain one.
        let scenario = Scenario(silentOn: .spendingTheCode)

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then
        #expect(outcome == .neverAnswered(.spendingTheCode))
        #expect(await scenario.server.codesOffered == [aLink.code])
    }

    @Test
    func `given a Mac that never says what it presented when pairing then the code counts as spent`() async {
        // given — reading back what was trusted is the one step with no timeout of its own on either
        // path, and it happens after the code has gone.
        let scenario = Scenario(silentOn: .readingTheKey)

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then
        #expect(outcome == .neverAnswered(.spendingTheCode))
    }

    @Test
    func `given a Keychain that never answers when pairing then the write is what is reported`() async {
        // given — the case this whole bound exists for: `SecItemAdd` is a call into another process
        // and nothing above it can call it off, so a wedged one used to end as a spinner with no
        // screen behind it.
        let scenario = Scenario(keychainNeverAnswering: true)

        // when
        let outcome = await scenario.sut.pair(with: .scanned(aLink), on: theMacTheReaderOpened, as: anIphone)

        // then — it carries the pairing, so the screen can offer the write on its own, exactly as a
        // refused write does.
        #expect(outcome == .neverAnswered(.writingTheKey(aPairedMac)))
    }

    @Test
    func `given a Keychain that never answers when the write is retried then it says so again`() async {
        // given
        let scenario = Scenario(keychainNeverAnswering: true)

        // when
        let outcome = await scenario.sut.saveToken(of: aPairedMac)

        // then
        #expect(outcome == .neverAnswered(.writingTheKey(aPairedMac)))
    }

    @Test
    func `given a Keychain that never enumerates when the history is read then nothing is claimed`() async {
        // given — the same reasoning as a Keychain that refuses, and the same answer: one more
        // pairing is not worth a Mac list that never arrives.
        let scenario = Scenario(keychainNeverAnswering: true)

        // when
        let known = await scenario.sut.rememberedMacs()

        // then
        #expect(known.isEmpty)
    }

    @Test
    func `given pairings with two Macs when the history is read then both are known`() async {
        // given — by the name a browse result carries, because that is the only thing a row can be
        // matched against: the identifier the Mac issues arrives inside a pairing response, which is
        // to say after the question has already been asked.
        let scenario = Scenario(remembering: [
            BonjourInstanceName(rawValue: "Davide's MacBook Pro"):
                RememberedMac(device: aPairedDevice, fingerprint: aLink.fingerprint, wakeAddresses: []),
            BonjourInstanceName(rawValue: "Mac Studio"):
                RememberedMac(device: aPairedDevice, fingerprint: anObservedKey, wakeAddresses: [])
        ])

        // when
        let known = await scenario.sut.rememberedMacs()

        // then
        #expect(known == [
            BonjourInstanceName(rawValue: "Davide's MacBook Pro"),
            BonjourInstanceName(rawValue: "Mac Studio")
        ])
    }

    @Test
    func `given a Keychain that will not enumerate when the history is read then nothing is claimed`() async {
        // given — the history only decides where a tap goes. Refusing to show the Macs that are
        // actually on the network because of it costs one pairing; the alternative costs the app.
        let scenario = Scenario(keychainRefusing: .unreadable)

        // when
        let known = await scenario.sut.rememberedMacs()

        // then
        #expect(known.isEmpty)
    }
}

// MARK: -

/// The one-shot the bound is built on, asserted directly.
///
/// Both of its rules are about the loser of a race, and `answer(from:)` gives a test no say in which
/// of the two tasks wins — so the sequence above can assert that a stall ends in a sentence, and
/// only this can assert what happens to the answer that arrives anyway.
@Suite("The first of two answers")
struct FirstAnswerTests {

    @Test
    func `given a caller already waiting when the step answers then that is what it reads`() async {
        // given — the ordinary shape: the sequence suspends on the one-shot, and whichever of the
        // step and the patience gets there first is what wakes it.
        let first = FirstAnswer<String>()
        let waiting = Task { await first.answer() }

        // when
        await first.settle(on: "the Mac said yes")

        // then
        #expect(await waiting.value == "the Mac said yes")
    }

    @Test
    func `given an answer that arrived first when it is read then it comes back rather than waiting`() async {
        // given — a step that answers before the caller gets round to reading, which is every step
        // on a Mac that is awake. Suspending here would be a sequence waiting for an answer it
        // already has, and nothing would ever resume it.
        let first = FirstAnswer<String>()
        await first.settle(on: "the Mac said yes")

        // when - then
        #expect(await first.answer() == "the Mac said yes")
    }

    @Test
    func `given the patience gave up when the step answers anyway then the giving up stands`() async {
        // given — the shape of every stall this bound produces. The step was never cancellable, so
        // it finishes eventually, and by then the reader has been told the attempt ended; a second
        // answer that replaced the first would be a screen changing under somebody who has moved on.
        let first = FirstAnswer<String>()
        await first.settle(on: nil)

        // when
        await first.settle(on: "the Mac said yes, forty seconds late")

        // then
        #expect(await first.answer() == nil)
    }
}

// MARK: -

private struct Scenario {

    let sut: MacPairing
    let macs: FakeRememberedMacStore
    let server: FakeServerPairing

    init(
        servingApiVersion apiVersion: Int = Branding.apiVersion,
        refusingHealth healthRefusal: ApiFailure? = nil,
        pairing: Result<PairedDevice, ApiFailure> = .success(aPairedDevice),
        presenting key: SpkiFingerprint? = aLink.fingerprint,
        remembering held: [BonjourInstanceName: RememberedMac] = [:],
        keychainRefusing refusal: RememberedMacStoreFailure? = nil,
        keychainNeverAnswering isKeychainSilent: Bool = false,
        silentOn: FakeServerPairing.SilentStep? = nil,
        servingWakeAddresses wakeAddresses: [String]? = nil
    ) {
        if isKeychainSilent {
            macs = FakeRememberedMacStore(neverAnswering: ())
        } else {
            macs = refusal.map(FakeRememberedMacStore.init(refusing:)) ?? FakeRememberedMacStore(holding: held)
        }
        let health: Result<HealthResponse, ApiFailure> = if let healthRefusal {
            .failure(healthRefusal)
        } else {
            .success(
                HealthResponse(
                    name: "Granita",
                    apiVersion: apiVersion,
                    serverVersion: "0.0.9",
                    wakeAddresses: wakeAddresses
                )
            )
        }
        server = FakeServerPairing(
            answeringHealth: health,
            answeringPairing: pairing,
            presenting: key,
            silentOn: silentOn
        )
        let mac = server
        // **The initialiser the app calls, wherever a test is not about the bound.** The shipped
        // patience is seventy-five seconds and no test can wait for it, so a sut built through the
        // seam every time would leave the one initialiser the composition root uses unrun — and a
        // default that stopped producing a working sequence would be nobody's failing test.
        if isKeychainSilent || silentOn != nil {
            // Milliseconds, because what is under test here is that a step which never answers still
            // ends in an outcome — not how long the reader waits for it.
            sut = MacPairing(macs: macs, handshake: { _ in mac }, patience: .milliseconds(50))
        } else {
            sut = MacPairing(macs: macs, handshake: { _ in mac })
        }
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
    id: BonjourInstanceName(rawValue: "Davide's MacBook Pro._granita._tcp.local."),
    name: "Davide's MacBook Pro"
)

/// What the scanned path ends up holding: the pin arrived with the link.
private let aPairedMac = PairedMac(
    instance: theMacTheReaderOpened.id,
    name: theMacTheReaderOpened.name,
    device: aPairedDevice,
    address: anAddress,
    fingerprint: aLink.fingerprint,
    wakeAddresses: []
)

/// The same pairing, wakeable. A function rather than a second constant, because what these tests
/// vary is only the addresses health reported.
private func aPairedMac(wakingAt addresses: [String]) -> PairedMac {
    PairedMac(
        instance: theMacTheReaderOpened.id,
        name: theMacTheReaderOpened.name,
        device: aPairedDevice,
        address: anAddress,
        fingerprint: aLink.fingerprint,
        wakeAddresses: HardwareAddress.all(in: addresses)
    )
}

/// A key nothing told the phone about in advance, which is the whole of the spoken path.
private let anObservedKey = SpkiFingerprint(rawValue: "9f86d081884c7d659a2feaa0c55ad015")

private let sixWords = "cabin-cactus-camera-candle-harbour-lantern"
