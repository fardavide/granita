import Testing

import ClientConnectionDomain

@testable import ClientConnectionPresentation

/// One model for the unit. It carries the browse today; the pairing surface arrives with the screen
/// that reads it, and what joins a Mac is asserted where it lives, in `MacPairingTests`.
@Suite("Client connection model")
struct ClientConnectionModelTests {

    @Test
    func `given nothing has happened when created then it is idle`() {
        // given - when
        let scenario = Scenario(discovering: [])

        // then
        #expect(scenario.sut.discovery == .idle)
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
    }
}

// MARK: -

private struct Scenario {

    let sut: ClientConnectionModel

    init(discovering states: [DiscoveryState]) {
        sut = ClientConnectionModel(browsing: FakeServerDiscovery(states: states))
    }
}
