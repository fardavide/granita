import Foundation
import Testing

import ServerApiDomain
import ServerMacDomain

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

    @Test
    func `given the server binds when General is drawn then it says when it started serving`() async {
        // given — a rebind is invisible otherwise: the icon and the address are identical either
        // side of one, so the time is the only thing that says the server has just stood up again.
        let bound = Date(timeIntervalSince1970: 1_000)
        let scenario = Scenario(
            states: [.starting, .running(ServerEndpoint(host: "MacBook-Pro.local", port: 59_144))],
            now: bound
        )

        // when
        await scenario.sut.followServer()

        // then
        #expect(scenario.sut.servingSince == bound)
    }

    @Test
    func `given the server never bound when General is drawn then it claims no serving time`() async {
        // given
        let scenario = Scenario(states: [.starting, .failed(reason: "the local network is blocked")])

        // when
        await scenario.sut.followServer()

        // then — a time left over from a run that did not happen is worse than no time.
        #expect(scenario.sut.servingSince == nil)
    }

    @Test
    func `given the server is up when Restart is pressed then it is asked to stand up again`() async {
        // given — the failure Restart exists for has no notification behind it: a Mac that changed
        // network keeps running and stops being reachable, and nothing tells the app so.
        let scenario = Scenario()

        // when
        await scenario.sut.restartServer()

        // then
        #expect(await scenario.restarts.count() == 1)
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
            outcome: .refused(.unknownToken),
            occurrences: 1
        )
        let accepted = ConnectionAttempt(
            id: UUID(),
            at: Date(timeIntervalSince1970: 1_060),
            source: "192.168.1.9",
            outcome: .accepted(device: "Davide's iPad"),
            occurrences: 1
        )
        let scenario = Scenario(states: [], readings: [[accepted], [refused, accepted]])

        // when
        await scenario.sut.followConnections()

        // then
        #expect(scenario.sut.connectionAttempts == [refused, accepted])
    }

    // MARK: - Opening at login, as the General tab draws it

    @Test
    func `given Granita already opens at login when General is opened then the toggle is on`() async {
        // given — read rather than remembered. Login Items in System Settings can turn this off
        // while Granita is not running, so a value cached from the last launch would be a toggle
        // that disagrees with the system it is reporting.
        let scenario = Scenario(opensAtLogin: true)

        // when
        await scenario.sut.loadLoginItem()

        // then
        #expect(scenario.sut.loginItem == .on)
    }

    @Test
    func `given the toggle is off when it is turned on then Granita opens at login`() async {
        // given
        let scenario = Scenario(opensAtLogin: false)

        // when
        await scenario.sut.setLoginItem(enabled: true)

        // then
        #expect(scenario.sut.loginItem == .on)
    }

    @Test
    func `given the toggle is on when it is turned off then Granita stops opening at login`() async {
        // given
        let scenario = Scenario(opensAtLogin: true)

        // when
        await scenario.sut.setLoginItem(enabled: false)

        // then
        #expect(scenario.sut.loginItem == .off)
    }

    @Test
    func `given macOS refuses the registration when the toggle is turned on then it goes back off and says why`() async {
        // given — the refusals a person actually hits are Login Items managed by a configuration
        // profile and an app registering from somewhere it will not be next launch, and macOS's
        // own words are the only thing that tells those two apart.
        let scenario = Scenario(
            opensAtLogin: false,
            loginItemFailure: .refused(reason: "Operation not permitted")
        )

        // when
        await scenario.sut.setLoginItem(enabled: true)

        // then — off, not on. A toggle left on for a registration that did not happen is the one
        // reading on this tab that is actively false.
        #expect(scenario.sut.loginItem == .refused(reason: "Operation not permitted"))
    }

    @Test
    func `given macOS has not approved Granita when the toggle is turned on then it waits rather than claiming to be on`() async {
        // given — the ordinary first-run outcome, and the one most easily mistaken for success:
        // `register()` returns without throwing and nothing starts at the next login.
        let scenario = Scenario(opensAtLogin: false, loginItemFailure: .notApproved)

        // when
        await scenario.sut.setLoginItem(enabled: true)

        // then
        #expect(scenario.sut.loginItem == .awaitingApproval)
    }

    @Test
    func `given a refusal on screen when the reader fixes it and turns the toggle on then the refusal goes`() async {
        // given — the whole point of naming the refusal is that it can be acted on, so the state
        // after acting on it has to be reachable.
        let scenario = Scenario(
            opensAtLogin: false,
            loginItemFailure: .refused(reason: "Operation not permitted")
        )
        await scenario.sut.setLoginItem(enabled: true)

        // when
        await scenario.loginItems.stopRefusing()
        await scenario.sut.setLoginItem(enabled: true)

        // then
        #expect(scenario.sut.loginItem == .on)
    }
}

// MARK: -

private struct Scenario {

    let sut: ServerMacModel
    let loginItems: FakeLoginItemRegistry
    let restarts: FakeServerRestarting

    init(
        states: [ServerRunState] = [],
        readings: [[ConnectionAttempt]] = [],
        opensAtLogin: Bool = false,
        loginItemFailure: LoginItemFailure? = nil,
        now: Date = Date(timeIntervalSince1970: 0)
    ) {
        loginItems = FakeLoginItemRegistry(isRegistered: opensAtLogin, failure: loginItemFailure)
        restarts = FakeServerRestarting()
        sut = ServerMacModel(
            host: FakeServerHost(states: states),
            restarts: restarts,
            connectionLog: FakeConnectionLog(readings: readings),
            loginItems: loginItems,
            now: { now }
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
