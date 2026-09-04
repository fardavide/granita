import Testing

import ClientConnectionDomain
import CorePairingDomain

/// The browse that wakes the Macs it is about to look for.
///
/// Two promises, and the second matters more than the first: every remembered Mac is woken, and
/// **nothing about the wake may cost the reader the browse**. A Keychain that will not answer or a
/// network that will not take a datagram must leave the Macs that are awake exactly as findable as
/// they were.
@Suite("Waking server discovery")
struct WakingServerDiscoveryTests {

    // MARK: - Waking

    @Test
    func `given two remembered Macs when the browse begins then every address is woken`() async throws {
        // given
        let scenario = Scenario(
            remembering: [
                "MacBook Pro": ["3e:2d:c6:c3:4b:fe"],
                "Mac Studio": ["a4:83:e7:11:22:33", "aa:bb:cc:dd:ee:ff"]
            ]
        )

        // when
        await scenario.browseToCompletion()

        // then
        #expect(
            await scenario.waking.allWoken.map(\.text).sorted()
                == ["3e:2d:c6:c3:4b:fe", "a4:83:e7:11:22:33", "aa:bb:cc:dd:ee:ff"]
        )
    }

    @Test
    func `given no remembered Mac when the browse begins then nothing is woken`() async throws {
        // given — the first launch, where there is nothing to wake and no packet worth sending.
        let scenario = Scenario(remembering: [:])

        // when
        await scenario.browseToCompletion()

        // then
        #expect(await scenario.waking.woken.isEmpty)
    }

    @Test
    func `given a remembered Mac with no hardware address when the browse begins then nothing is woken`() async throws {
        // given — a Mac paired with before health reported an address, which is every Mac already
        // paired with when this ships.
        let scenario = Scenario(remembering: ["MacBook Pro": []])

        // when
        await scenario.browseToCompletion()

        // then — no packet at all, rather than an empty one.
        #expect(await scenario.waking.woken.isEmpty)
    }

    // MARK: - Leaving the browse alone

    @Test
    func `given a browse that reports Macs when it is decorated then the states pass through unchanged`() async throws {
        // given
        let found = DiscoveryState.found([DiscoveredServer(id: BonjourInstanceName(rawValue: "M"), name: "MacBook Pro")])
        let scenario = Scenario(remembering: ["MacBook Pro": ["3e:2d:c6:c3:4b:fe"]], reporting: [.searching, found])

        // when
        let states = await scenario.states()

        // then
        #expect(states == [.searching, found])
    }

    @Test
    func `given a Keychain that refuses when the browse begins then the browse still reports its Macs`() async throws {
        // given — the wake is unreachable and the reader must not be able to tell.
        let scenario = Scenario(keychainRefusing: .refused(status: -25308), reporting: [.searching, .found([])])

        // when
        let states = await scenario.states()

        // then
        #expect(states == [.searching, .found([])])
        #expect(await scenario.waking.woken.isEmpty)
    }

    @Test
    func `given a browse that refuses local network access when it is decorated then that reaches the reader`() async throws {
        // given — the one refusal the reader can act on, and a decorator that swallowed it would
        // leave them looking at an empty list with no way to learn why.
        let scenario = Scenario(remembering: [:], reporting: [.localNetworkDenied])

        // when
        let states = await scenario.states()

        // then
        #expect(states == [.localNetworkDenied])
    }
}

// MARK: -

private struct Scenario {

    let sut: any ServerDiscovering
    let waking = FakeMacWaking()

    private let macs: FakeRememberedMacStore

    init(
        remembering: [String: [String]] = [:],
        keychainRefusing refusal: RememberedMacStoreFailure? = nil,
        reporting states: [DiscoveryState] = [.searching, .found([])]
    ) {
        var held: [BonjourInstanceName: RememberedMac] = [:]
        for (name, addresses) in remembering {
            held[BonjourInstanceName(rawValue: name)] = RememberedMac(
                device: PairedDevice(
                    token: PairingToken(rawValue: "token-\(name)"),
                    deviceId: DeviceId(rawValue: "device-\(name)"),
                    serverInstanceId: ServerInstanceId(rawValue: "server-\(name)")
                ),
                fingerprint: SpkiFingerprint(rawValue: "fingerprint-\(name)"),
                wakeAddresses: HardwareAddress.all(in: addresses)
            )
        }
        macs = refusal.map(FakeRememberedMacStore.init(refusing:)) ?? FakeRememberedMacStore(holding: held)
        sut = WakingServerDiscovery(
            discovery: FakeDiscovery(reporting: states),
            macs: macs,
            waking: waking
        )
    }

    /// Drains the stream, which is also what waits for the wake beside it: the decorator finishes
    /// its stream only after the browse it wraps has, and the wake is spawned before either.
    func browseToCompletion() async {
        _ = await states()
    }

    func states() async -> [DiscoveryState] {
        var seen: [DiscoveryState] = []
        for await state in sut.discover() {
            seen.append(state)
        }
        // The wake runs beside the browse rather than in front of it, so draining the stream does
        // not by itself prove the wake has landed. Yielding lets the detached task finish.
        for _ in 0..<50 {
            if await waking.woken.isEmpty == false { break }
            await Task.yield()
        }
        return seen
    }
}

// MARK: -

/// A browse that reports what it was told to and then ends.
private struct FakeDiscovery: ServerDiscovering {

    let states: [DiscoveryState]

    init(reporting states: [DiscoveryState]) {
        self.states = states
    }

    func discover() -> AsyncStream<DiscoveryState> {
        let states = states
        return AsyncStream { continuation in
            for state in states {
                continuation.yield(state)
            }
            continuation.finish()
        }
    }
}
