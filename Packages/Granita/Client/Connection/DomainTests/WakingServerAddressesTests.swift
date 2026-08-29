import Synchronization
import Testing

import ClientConnectionDomain
import CorePairingDomain

/// The resolve that wakes the Mac and asks again.
///
/// The patience is injected as an empty list or as zero-length waits throughout, so these assert the
/// sequence of attempts rather than the clock — a test that actually waited fifteen seconds would be
/// a test nobody runs.
@Suite("Waking server addresses")
struct WakingServerAddressesTests {

    @Test
    func `given a Mac that answers at once when it is asked then no wake is sent`() async throws {
        // given
        let scenario = Scenario(answering: [.success(anAddress)])

        // when
        let address = try await scenario.sut.address(of: aServer)

        // then — a Mac that was awake all along must cost no packets and no delay.
        #expect(address == anAddress)
        #expect(await scenario.waking.woken.isEmpty)
        #expect(scenario.addresses.lookups == 1)
    }

    @Test
    func `given a Mac that is unreachable when it has a known hardware address then it is woken and asked again`() async throws {
        // given
        let scenario = Scenario(
            answering: [.failure(.unreachable(diagnostic: "asleep")), .success(anAddress)],
            remembering: ["3e:2d:c6:c3:4b:fe"]
        )

        // when
        let address = try await scenario.sut.address(of: aServer)

        // then
        #expect(address == anAddress)
        #expect(await scenario.waking.allWoken.map(\.text) == ["3e:2d:c6:c3:4b:fe"])
        #expect(scenario.addresses.lookups == 2)
    }

    @Test
    func `given a Mac that stays unreachable when every attempt is spent then the last failure reaches the reader`() async throws {
        // given — three waits, so four attempts in all.
        let scenario = Scenario(
            answering: [
                .failure(.unreachable(diagnostic: "first")),
                .failure(.unreachable(diagnostic: "second")),
                .failure(.unreachable(diagnostic: "third")),
                .failure(.unreachable(diagnostic: "last"))
            ],
            remembering: ["3e:2d:c6:c3:4b:fe"]
        )

        // when
        let failure = await #expect(throws: ServerAddressResolutionFailure.self) {
            try await scenario.sut.address(of: aServer)
        }

        // then — the final attempt's diagnostic, not the first: it is the one whose timing the
        // reader watched, and the small print under the sentence should name it.
        #expect(failure == .unreachable(diagnostic: "last"))
        #expect(scenario.addresses.lookups == 4)
    }

    @Test
    func `given a Mac that refuses local network access when it is asked then it is not woken or retried`() async throws {
        // given
        let scenario = Scenario(answering: [.failure(.localNetworkDenied)], remembering: ["3e:2d:c6:c3:4b:fe"])

        // when
        let failure = await #expect(throws: ServerAddressResolutionFailure.self) {
            try await scenario.sut.address(of: aServer)
        }

        // then — the one refusal a reader can fix, said at once rather than after fifteen seconds
        // of packets that could never have helped.
        #expect(failure == .localNetworkDenied)
        #expect(scenario.addresses.lookups == 1)
        #expect(await scenario.waking.woken.isEmpty)
    }

    @Test
    func `given a Mac with no known hardware address when it is unreachable then it is still asked again`() async throws {
        // given — a Mac paired with before health carried an address. It cannot be woken, but it
        // may simply have been slow, and the retry is free.
        let scenario = Scenario(
            answering: [.failure(.unreachable(diagnostic: "slow")), .success(anAddress)],
            remembering: []
        )

        // when
        let address = try await scenario.sut.address(of: aServer)

        // then
        #expect(address == anAddress)
        #expect(await scenario.waking.woken.isEmpty)
        #expect(scenario.addresses.lookups == 2)
    }

    @Test
    func `given no patience at all when the Mac is unreachable then it is asked exactly once`() async throws {
        // given — the seam itself, proving the retries come from the patience rather than from a
        // count hidden in the implementation.
        let scenario = Scenario(
            answering: [.failure(.unreachable(diagnostic: "asleep"))],
            remembering: ["3e:2d:c6:c3:4b:fe"],
            patience: []
        )

        // when
        _ = await #expect(throws: ServerAddressResolutionFailure.self) {
            try await scenario.sut.address(of: aServer)
        }

        // then
        #expect(scenario.addresses.lookups == 1)
    }

    @Test
    func `given a patience that actually waits when the Mac answers late then the wait happens between attempts`() async throws {
        // given — a real wait rather than zero, so the sleep between attempts is exercised. A
        // millisecond, because what is asserted is that it waits at all and not for how long.
        let scenario = Scenario(
            answering: [.failure(.unreachable(diagnostic: "asleep")), .success(anAddress)],
            remembering: ["3e:2d:c6:c3:4b:fe"],
            patience: [.milliseconds(1)]
        )

        // when
        let address = try await scenario.sut.address(of: aServer)

        // then
        #expect(address == anAddress)
        #expect(scenario.addresses.lookups == 2)
    }

    @Test
    func `given the reader leaves while the Mac is being waited for then the wait ends instead of holding them`() async throws {
        // given — a wait long enough that nothing could outrun it, so what ends this is the
        // cancellation and not the clock.
        let scenario = Scenario(
            answering: [.failure(.unreachable(diagnostic: "asleep"))],
            remembering: ["3e:2d:c6:c3:4b:fe"],
            patience: [.seconds(60)]
        )

        // when — started, then cancelled the way leaving the screen cancels its task.
        let resolving = Task { try await scenario.sut.address(of: aServer) }
        while scenario.addresses.lookups < 1 {
            await Task.yield()
        }
        resolving.cancel()

        // then — it gives up rather than sleeping out the minute, and says the last thing that
        // actually went wrong.
        let failure = await #expect(throws: ServerAddressResolutionFailure.self) {
            try await resolving.value
        }
        #expect(failure == .unreachable(diagnostic: "asleep"))
        #expect(scenario.addresses.lookups == 1)
    }

    @Test
    func `given the shipped patience then it waits about fifteen seconds across three further attempts`() {
        // given - when - then — the number a reader waits before being told the Mac is unreachable.
        // Asserted so that changing it is a deliberate act with a failing test behind it.
        #expect(WakingServerAddresses.defaultPatience == [.seconds(2), .seconds(5), .seconds(8)])
    }
}

// MARK: -

private let aServer = DiscoveredServer(id: BonjourInstanceName(rawValue: "MacBook Pro"), name: "MacBook Pro")
private let anAddress = ServerAddress(host: "macbook-pro.local", port: 59144)

private struct Scenario {

    let sut: WakingServerAddresses
    let waking = FakeMacWaking()
    let addresses: SequencedResolver

    init(
        answering answers: [Result<ServerAddress, ServerAddressResolutionFailure>],
        remembering wakeAddresses: [String] = [],
        patience: [Duration] = [.zero, .zero, .zero]
    ) {
        addresses = SequencedResolver(answering: answers)
        let held: [BonjourInstanceName: RememberedMac] = [
            aServer.id: RememberedMac(
                device: PairedDevice(
                    token: PairingToken(rawValue: "token"),
                    deviceId: DeviceId(rawValue: "device"),
                    serverInstanceId: ServerInstanceId(rawValue: "server")
                ),
                fingerprint: SpkiFingerprint(rawValue: "fingerprint"),
                wakeAddresses: HardwareAddress.all(in: wakeAddresses)
            )
        ]
        sut = WakingServerAddresses(
            addresses: addresses,
            macs: FakeRememberedMacStore(holding: held),
            waking: waking,
            patience: patience
        )
    }
}

// MARK: -

/// A resolver that answers differently each time, which is the whole subject here: one attempt is
/// not a retry, and a fake with one answer cannot tell them apart.
final class SequencedResolver: ServerAddressResolving {

    var lookups: Int { asked.withLock { $0 } }

    private let answers: [Result<ServerAddress, ServerAddressResolutionFailure>]
    private let asked = Mutex(0)

    init(answering answers: [Result<ServerAddress, ServerAddressResolutionFailure>]) {
        self.answers = answers
    }

    func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        let index = asked.withLock { count -> Int in
            defer { count += 1 }
            return count
        }
        // Past the end means the subject asked more times than the test said it would, which is a
        // failure of the subject rather than of the fake — so it repeats the last answer and lets
        // the lookup count be what fails.
        switch answers[min(index, answers.count - 1)] {
        case .success(let address): return address
        case .failure(let failure): throw failure
        }
    }
}
