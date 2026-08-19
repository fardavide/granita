import ClientConnectionDomain
import Testing

@testable import ClientConnectionPresentation

@Suite("Server discovery view model")
struct ServerDiscoveryViewModelTests {

    @Test
    func `given nothing has happened when created then it is idle`() {
        // given - when
        let scenario = Scenario(states: [])

        // then
        #expect(scenario.sut.state == .idle)
    }

    @Test
    func `given a server is nearby when searching then it is offered`() async {
        // given
        let mac = DiscoveredServer(id: "Davide's MacBook Pro", name: "Davide's MacBook Pro")
        let scenario = Scenario(states: [.searching, .found([mac])])

        // when
        await scenario.sut.start()

        // then
        #expect(scenario.sut.state == .found([mac]))
    }

    @Test
    func `given permission is refused when searching then that is reported as its own state`() async {
        // given — a denial is not a failure the user can only stare at: it is the one they can fix.
        let scenario = Scenario(states: [.searching, .localNetworkDenied])

        // when
        await scenario.sut.start()

        // then
        #expect(scenario.sut.state == .localNetworkDenied)
        #expect(scenario.sut.isPermissionRefused)
    }

    @Test
    func `given a server disappears when searching then the list empties without erroring`() async {
        // given — a Mac going to sleep is the common case, not an error.
        let mac = DiscoveredServer(id: "MacBook", name: "MacBook")
        let scenario = Scenario(states: [.found([mac]), .found([])])

        // when
        await scenario.sut.start()

        // then
        #expect(scenario.sut.state == .found([]))
        #expect(scenario.sut.isPermissionRefused == false)
    }
}

// MARK: -

private struct Scenario {

    let sut: ServerDiscoveryViewModel

    init(states: [DiscoveryState]) {
        sut = ServerDiscoveryViewModel(discovery: FakeServerDiscovery(states: states))
    }
}

private struct FakeServerDiscovery: ServerDiscovering {

    let states: [DiscoveryState]

    func discover() -> AsyncStream<DiscoveryState> {
        AsyncStream { continuation in
            for state in states { continuation.yield(state) }
            continuation.finish()
        }
    }
}
