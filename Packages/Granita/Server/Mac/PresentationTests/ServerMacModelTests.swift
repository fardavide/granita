import Foundation
import Testing

import CoreDiffDomain
import ServerApiDomain
import ServerMacDomain
import ServerStoreDomain

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

    // MARK: - What Advanced reports

    @Test
    func `given Advanced is opened when git is asked for then it says which one and what version`() async {
        // given — the row runs git rather than reporting the path that won, because a path that is
        // executable and broken looks exactly like a working one until something runs it.
        let scenario = Scenario(git: .available(version: "2.52.0", path: "/opt/homebrew/bin/git"))

        // when
        await scenario.sut.loadGitInstallation()

        // then
        #expect(scenario.sut.gitInstallation == .available(version: "2.52.0", path: "/opt/homebrew/bin/git"))
    }

    @Test
    func `given git cannot be run when Advanced is opened then the row carries git's own words`() async {
        // given — the rule the whole git API already follows, and the one failure a reader can
        // actually act on: the command line tools point at a developer directory that is not there.
        let scenario = Scenario(git: .unavailable(reason: "xcrun: error: invalid active developer path"))

        // when
        await scenario.sut.loadGitInstallation()

        // then
        #expect(scenario.sut.gitInstallation == .unavailable(reason: "xcrun: error: invalid active developer path"))
    }

    @Test
    func `given nothing has asked yet when Advanced is drawn then git reads as still being checked`() {
        // given - when - then — a row that appears a moment after the pane does reads as a glitch,
        // so the state before the answer is drawn rather than hidden.
        #expect(Scenario().sut.gitInstallation == .checking)
    }

    @Test
    func `given projects and devices when Advanced is opened then Reset says what it would destroy`() async {
        // given — the sentence above the button is what makes the button proportionate, and it is
        // counted from the store rather than guessed.
        let scenario = Scenario(
            projects: [storedProject(named: "Granita"), storedProject(named: "Oltre")],
            devices: [storedDevice(named: "iPhone"), storedDevice(named: "iPad")]
        )

        // when
        await scenario.sut.loadStoredCounts()

        // then
        #expect(scenario.sut.storedProjectCount == 2)
        #expect(scenario.sut.storedDeviceCount == 2)
    }

    @Test
    func `given a store with things in it when it is reset then everything goes and the counts follow`() async {
        // given
        let scenario = Scenario(
            projects: [storedProject(named: "Granita")],
            devices: [storedDevice(named: "iPhone")]
        )
        await scenario.sut.loadStoredCounts()

        // when
        await scenario.sut.resetAllData()

        // then — the counts are re-read rather than assumed, so a refused reset leaves the sentence
        // describing what is still there.
        #expect(await scenario.store.resets == 1)
        #expect(scenario.sut.storedProjectCount == 0)
        #expect(scenario.sut.storedDeviceCount == 0)
    }

    @Test
    func `given a store that will not write when a reset is asked for then the counts stay truthful`() async {
        // given — the disk is full, or the document is one a newer Granita wrote. Either way
        // nothing was destroyed, and a tab that then said "no projects" would be lying about the
        // one thing here that matters.
        let scenario = Scenario(
            projects: [storedProject(named: "Granita")],
            storeFailure: .notWritable(reason: "The volume is out of space.")
        )
        await scenario.sut.loadStoredCounts()

        // when
        await scenario.sut.resetAllData()

        // then
        #expect(scenario.sut.storedProjectCount == 1)
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
    let store: FakeStore

    init(
        states: [ServerRunState] = [],
        readings: [[ConnectionAttempt]] = [],
        opensAtLogin: Bool = false,
        loginItemFailure: LoginItemFailure? = nil,
        git: GitInstallation = .checking,
        projects: [StoredProject] = [],
        devices: [StoredDevice] = [],
        storeFailure: StoreError? = nil,
        now: Date = Date(timeIntervalSince1970: 0)
    ) {
        loginItems = FakeLoginItemRegistry(isRegistered: opensAtLogin, failure: loginItemFailure)
        restarts = FakeServerRestarting()
        store = FakeStore(projects: projects, devices: devices, failure: storeFailure)
        sut = ServerMacModel(
            host: FakeServerHost(states: states),
            restarts: restarts,
            connectionLog: FakeConnectionLog(readings: readings),
            loginItems: loginItems,
            gitInstallations: FakeGitInstallations(installation: git),
            store: store,
            dataFolderUrl: URL(filePath: "/Users/davide/Library/Application Support/Granita"),
            now: { now }
        )
    }
}

private func storedProject(named name: String) -> StoredProject {
    StoredProject(id: ProjectID(canonicalPath: "/\(name)"), path: "/\(name)", name: name, isVisible: true)
}

private func storedDevice(named name: String) -> StoredDevice {
    StoredDevice(
        id: name,
        name: name,
        platform: "iOS",
        tokenHash: "hash-\(name)",
        pairedAt: Date(timeIntervalSince1970: 1)
    )
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
