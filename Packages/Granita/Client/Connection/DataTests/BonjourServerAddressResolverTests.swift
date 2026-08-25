import Testing

import ClientConnectionDomain
@testable import ClientConnectionData

/// The six-word path has a Mac's name and no way to reach it. What this pins is the four ways that
/// lookup ends, and the promise that holds across all of them: nothing is left connected.
@Suite("Bonjour server address resolver")
struct BonjourServerAddressResolverTests {

    @Test
    func `given the Mac answered when its address is asked for then that is where it is`() async throws {
        // given — a browse result and nothing more, which is the whole reason this type exists.
        let mac = DiscoveredServer(id: "Davide's MacBook Pro", name: "Davide's MacBook Pro")
        let scenario = Scenario(
            answering: .says(.reached(ServerAddress(host: "192.168.1.24", port: 51_763))),
            patience: .seconds(60)
        )

        // when
        let address = try await scenario.sut.address(of: mac)

        // then
        #expect(address == ServerAddress(host: "192.168.1.24", port: 51_763))
    }

    @Test
    func `given the Mac answered when its address is asked for then nothing is left connected`() async throws {
        // given
        let mac = DiscoveredServer(id: "Davide's MacBook Pro", name: "Davide's MacBook Pro")
        let scenario = Scenario(
            answering: .says(.reached(ServerAddress(host: "192.168.1.24", port: 51_763))),
            patience: .seconds(60)
        )

        // when
        _ = try await scenario.sut.address(of: mac)

        // then — a connection nobody is listening to is a socket and an mDNS query held open for as
        // long as the app lives, and the path where it answered is the one where forgetting is
        // easiest.
        #expect(scenario.connection.isCancelled)
    }

    @Test
    func `given nothing answers for that Mac when its address is asked for then the reason is passed through`() async {
        // given — whatever the connection concluded, verbatim: this layer adds no reading of its own
        // to a diagnosis the state handler already made.
        let mac = DiscoveredServer(id: "Davide's MacBook Pro", name: "Davide's MacBook Pro")
        let scenario = Scenario(
            answering: .says(.lost(.unreachable(diagnostic: "No such record\nNWError -72004"))),
            patience: .seconds(60)
        )

        // when - then
        await #expect(throws: ServerAddressResolutionFailure.unreachable(diagnostic: "No such record\nNWError -72004")) {
            try await scenario.sut.address(of: mac)
        }
    }

    @Test
    func `given the Mac may not be reached at all when its address is asked for then that is not a fault`() async {
        // given — the refusal survives the trip rather than being flattened into "could not reach
        // it", because the two do not share a remedy.
        let mac = DiscoveredServer(id: "Davide's MacBook Pro", name: "Davide's MacBook Pro")
        let scenario = Scenario(answering: .says(.lost(.localNetworkDenied)), patience: .seconds(60))

        // when - then
        await #expect(throws: ServerAddressResolutionFailure.localNetworkDenied) {
            try await scenario.sut.address(of: mac)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a Mac that never answers when patience runs out then it is unreachable`() async {
        // given — a connection that says nothing and never stops, which is what a Mac that has left
        // the network looks like to a connection still hoping. Without a limit this is the state the
        // screen sits in for ever.
        let mac = DiscoveredServer(id: "Davide's MacBook Pro", name: "Davide's MacBook Pro")
        let scenario = Scenario(answering: .saysNothingEver, patience: .zero)

        // when - then
        await #expect(
            throws: ServerAddressResolutionFailure.unreachable(
                diagnostic: "the Mac did not say where it was before the connection ended"
            )
        ) {
            try await scenario.sut.address(of: mac)
        }
    }
}

// MARK: -

private struct Scenario {

    let connection: FakeServiceConnection

    let sut: BonjourServerAddressResolver

    /// `patience` replaces the resolver's own five seconds, so a test that means "this Mac never
    /// answers" says `.zero` and every other test says long enough that the connection always wins
    /// the race rather than sometimes.
    init(answering answer: FakeConnectionAnswer, patience: Duration) {
        let connection = FakeServiceConnection(answering: answer)
        self.connection = connection
        sut = BonjourServerAddressResolver(makeConnection: { _ in connection }, patience: patience)
    }
}
