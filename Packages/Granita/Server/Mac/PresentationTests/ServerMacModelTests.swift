import Foundation
import Testing

import ServerApiDomain

@testable import ServerMacPresentation

@Suite("Server Mac model")
struct ServerMacModelTests {

    // MARK: - The server, as the status item reports it

    @Test
    func `given the server binds when the menu is opened then it says where it is listening`() async {
        // given — the status line is how someone at the Mac tells "it is up" from "it is up
        // somewhere else", and with a Bonjour bind the port is the system's choice rather than ours.
        let endpoint = ServerEndpoint(host: "MacBook-Pro.local", port: 59_144)
        let scenario = Scenario(states: [.starting, .running(endpoint)], readings: [])

        // when
        await scenario.sut.followServer()

        // then
        #expect(scenario.sut.serverState == .running(endpoint))
    }

    @Test
    func `given the app has only just launched when the menu is opened then the server reads as coming up`() {
        // given - when
        let scenario = Scenario(states: [], readings: [])

        // then — the app starts the server as it starts itself, so "not serving" would be a lie
        // told for the first fraction of a second, on the one surface that is always on screen.
        #expect(scenario.sut.serverState == .starting)
    }

    // MARK: - The connection log, as the Advanced panel draws it

    @Test
    func `given the panel is open when another phone is turned away then its row arrives unasked`() async {
        // given — the panel is opened *because* something is failing, so what it holds when it
        // opens is not the interesting part.
        let refused = ConnectionAttempt(
            id: UUID(),
            at: Date(timeIntervalSince1970: 1_000),
            source: "192.168.1.24",
            outcome: .refused(.unknownToken)
        )
        let accepted = ConnectionAttempt(
            id: UUID(),
            at: Date(timeIntervalSince1970: 1_060),
            source: "192.168.1.9",
            outcome: .accepted(device: "Davide's iPad")
        )
        let scenario = Scenario(states: [], readings: [[accepted], [refused, accepted]])

        // when
        await scenario.sut.followConnections()

        // then
        #expect(scenario.sut.connectionAttempts == [refused, accepted])
    }
}

// MARK: -

private struct Scenario {

    let sut: ServerMacModel

    init(states: [ServerRunState], readings: [[ConnectionAttempt]]) {
        sut = ServerMacModel(
            host: FakeServerHost(states: states),
            connectionLog: FakeConnectionLog(readings: readings)
        )
    }
}

private struct FakeServerHost: ServerHosting {

    let states: [ServerRunState]

    func run() -> AsyncStream<ServerRunState> {
        AsyncStream { continuation in
            for state in states { continuation.yield(state) }
            continuation.finish()
        }
    }
}

private struct FakeConnectionLog: ConnectionLog {

    let readings: [[ConnectionAttempt]]

    func record(source: String, outcome: ConnectionOutcome) async {}

    func attempts() async -> AsyncStream<[ConnectionAttempt]> {
        AsyncStream { continuation in
            for reading in readings { continuation.yield(reading) }
            continuation.finish()
        }
    }
}
