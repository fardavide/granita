import Foundation
import Testing

import CoreDiagnosticsDomain
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
            outcome: .accepted(device: "Davide's iPad", id: "device-ipad"),
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

    // MARK: - The verbose switch, which is Advanced's half of the logging layer

    @Test
    func `given nobody has asked for everything when Advanced is drawn then verbose logging reads off`() {
        // given - when - then — off is the honest default rather than a cautious one. Verbose
        // records every request and every git invocation, which is a volume nobody wants until
        // they are looking for something.
        #expect(Scenario().sut.isVerboseLogging == false)
    }

    @Test
    func `given verbose logging was left on when Advanced is drawn then the switch reads on`() {
        // given — the setting outlives the app, so the switch has to arrive showing what the
        // server is already doing rather than what this launch defaulted to.
        let scenario = Scenario(isVerbose: true)

        // then
        #expect(scenario.sut.isVerboseLogging)
    }

    @Test
    func `given a server running since launch when the switch is turned on then the setting itself moves`() {
        // given — the whole reason verbosity is a seam rather than a `Bool` handed in at launch:
        // the server reading it has been up since the app started, so what the switch must move is
        // the stored setting the server re-reads per line. Writing only the model's own copy would
        // be a switch that does nothing until the next launch.
        let scenario = Scenario()

        // when
        scenario.sut.setVerboseLogging(true)

        // then
        #expect(scenario.verbosity.isVerbose)
        #expect(scenario.sut.isVerboseLogging)
    }

    @Test
    func `given verbose logging is on when the switch is turned off then the setting goes quiet again`() {
        // given
        let scenario = Scenario(isVerbose: true)

        // when
        scenario.sut.setVerboseLogging(false)

        // then
        #expect(scenario.verbosity.isVerbose == false)
        #expect(scenario.sut.isVerboseLogging == false)
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

    // MARK: - Projects, which is the security boundary

    @Test
    func `given projects the reader added when the tab opens then each says what is behind it`() async {
        // given
        let scenario = Scenario(
            projects: [storedProject(named: "granita"), storedProject(named: "oltre", isVisible: false)],
            folderContents: ["/granita": .worktrees(count: 4), "/oltre": .worktrees(count: 1)],
            worktreesWithChanges: ["/granita": 2]
        )

        // when
        await scenario.sut.loadProjects()

        // then
        #expect(scenario.sut.projects.map(\.name) == ["granita", "oltre"])
        #expect(scenario.sut.projects[0].contents == .worktrees(count: 4))
        #expect(scenario.sut.projects[0].isVisible)
        #expect(scenario.sut.projects[1].isVisible == false)
    }

    @Test
    func `given a project switched on when the tab opens then what has changed arrives after the row`(
    ) async {
        // given — the two figures cost two different amounts. Counting what has changed is one git
        // invocation per worktree, measured at 16.7 seconds for one monorepo's sixteen, so the row
        // is drawn from the cheap half and this arrives into it.
        let scenario = Scenario(
            projects: [storedProject(named: "granita")],
            folderContents: ["/granita": .worktrees(count: 4)],
            worktreesWithChanges: ["/granita": 2]
        )

        // when
        await scenario.sut.loadProjects()

        // then
        #expect(scenario.sut.projects[0].worktreesWithChanges == .counted(2))
    }

    @Test
    func `given a project switched off when the tab opens then nothing counts what changed in it`() async {
        // given — the expensive question is asked only of the projects whose figure is drawn. A
        // switched-off row reads "not visible" and has nowhere to put a count.
        let scenario = Scenario(
            projects: [storedProject(named: "oltre", isVisible: false)],
            folderContents: ["/oltre": .worktrees(count: 9)],
            worktreesWithChanges: ["/oltre": 3]
        )

        // when
        await scenario.sut.loadProjects()

        // then
        #expect(await scenario.folders.counted == [])
        #expect(scenario.sut.projects[0].worktreesWithChanges == .counting)
    }

    @Test
    func `given a project whose folder has gone when the tab opens then it says so rather than reading empty`(
    ) async {
        // given — today such a project still passes `isVisible`, so the API serves it with zero
        // worktrees, which on a phone is indistinguishable from a project with nothing to read.
        let scenario = Scenario(
            projects: [storedProject(named: "aura")],
            folderContents: ["/aura": .folderNotFound],
            worktreesWithChanges: [:]
        )

        // when
        await scenario.sut.loadProjects()

        // then — and nothing tried to count what changed inside a folder that is not there.
        #expect(scenario.sut.projects[0].contents == .folderNotFound)
        #expect(await scenario.folders.counted == [])
    }

    @Test
    func `given a project when its switch is turned on then it becomes visible and is counted`() async {
        // given
        let scenario = Scenario(
            projects: [storedProject(named: "oltre", isVisible: false)],
            folderContents: ["/oltre": .worktrees(count: 2)],
            worktreesWithChanges: ["/oltre": 1]
        )
        await scenario.sut.loadProjects()

        // when
        await scenario.sut.setProjectVisible(true, id: ProjectID(canonicalPath: "/oltre"))

        // then — a switch that changed nothing a reader can perceive would be the worst control on
        // the one tab that is the security boundary.
        #expect(scenario.sut.projects[0].isVisible)
        #expect(scenario.sut.projects[0].worktreesWithChanges == .counted(1))
    }

    @Test
    func `given the store refuses a switch when it is flipped then the tab says so and does not lie`(
    ) async {
        // given — a full disk, or a document a newer Granita wrote. Either way nothing was written.
        let scenario = Scenario(
            projects: [storedProject(named: "oltre", isVisible: false)],
            folderContents: ["/oltre": .worktrees(count: 2)],
            worktreesWithChanges: [:],
            storeFailure: .notWritable(reason: "No space left on device")
        )
        await scenario.sut.loadProjects()

        // when
        await scenario.sut.setProjectVisible(true, id: ProjectID(canonicalPath: "/oltre"))

        // then — the switch stays where the document says it is, and the reason is on screen. A
        // switch that sprang back with no explanation is a control that did nothing.
        #expect(scenario.sut.projects[0].isVisible == false)
        #expect(scenario.sut.projectsFailure == StoreWriteFailure(
            sentence: "That change could not be saved.",
            reason: "No space left on device"
        ))
    }

    @Test
    func `given a project when it is removed then it leaves the list`() async {
        // given
        let scenario = Scenario(
            projects: [storedProject(named: "granita"), storedProject(named: "oltre")],
            folderContents: ["/granita": .worktrees(count: 1), "/oltre": .worktrees(count: 1)],
            worktreesWithChanges: [:]
        )
        await scenario.sut.loadProjects()

        // when
        await scenario.sut.removeProject(id: ProjectID(canonicalPath: "/granita"))

        // then
        #expect(scenario.sut.projects.map(\.name) == ["oltre"])
    }

    // MARK: - Adding, which is the verb a scan may not perform

    @Test
    func `given a folder that is a repository when it is added then it arrives switched off`() async {
        // given — design §4's whole argument: adding puts a repository in the list and a switch
        // decides whether the phone can see it, and those are two separate acts.
        let scenario = Scenario(
            projects: [],
            folderContents: ["/picked": .worktrees(count: 1)],
            worktreesWithChanges: [:]
        )

        // when — a directory URL with the trailing separator `NSOpenPanel` really hands back. An
        // identifier is a hash of the path, so the same folder spelled two ways would be two
        // projects that cannot both be switched on.
        await scenario.sut.addProject(atFolder: URL(filePath: "/picked", directoryHint: .isDirectory))

        // then
        #expect(scenario.sut.projects.map(\.name) == ["picked"])
        #expect(scenario.sut.projects[0].path == "/picked")
        #expect(scenario.sut.projects[0].isVisible == false)
    }

    @Test
    func `given a folder that is not a repository when it is added then it is refused with a reason`(
    ) async {
        // given — a folder picker will offer any folder on this Mac, and a row reading "not a
        // repository" for something a reader chose a second ago is a worse answer than not adding it.
        let scenario = Scenario(
            projects: [],
            folderContents: ["/documents": .notARepository],
            worktreesWithChanges: [:]
        )

        // when
        await scenario.sut.addProject(atFolder: URL(filePath: "/documents"))

        // then
        #expect(scenario.sut.projects.isEmpty)
        #expect(scenario.sut.projectsFailure == StoreWriteFailure(
            sentence: "That folder is not a git repository.",
            reason: nil
        ))
    }

    @Test
    func `given a folder that is not there when it is added then it is refused with a reason`() async {
        // given — a folder can be picked and then moved before the panel is dismissed, and the
        // sentence has to be the true one rather than the one about repositories.
        let scenario = Scenario(projects: [], folderContents: [:], worktreesWithChanges: [:])

        // when
        await scenario.sut.addProject(atFolder: URL(filePath: "/gone"))

        // then
        #expect(scenario.sut.projects.isEmpty)
        #expect(scenario.sut.projectsFailure == StoreWriteFailure(
            sentence: "That folder is not there any more.",
            reason: nil
        ))
    }

    @Test
    func `given a document a newer Granita wrote when a switch is flipped then nothing is destroyed`(
    ) async {
        // given — the other refusal the store can give, and the one where repeating its words would
        // say nothing: there is no system string, only a fact about the document.
        let scenario = Scenario(
            projects: [storedProject(named: "oltre", isVisible: false)],
            folderContents: ["/oltre": .worktrees(count: 1)],
            worktreesWithChanges: [:],
            storeFailure: .documentIsFromANewerVersion
        )
        await scenario.sut.loadProjects()

        // when
        await scenario.sut.setProjectVisible(true, id: ProjectID(canonicalPath: "/oltre"))

        // then
        #expect(scenario.sut.projects[0].isVisible == false)
        #expect(scenario.sut.projectsFailure == StoreWriteFailure(
            sentence: "A newer version of Granita wrote this Mac's settings, so they were left alone.",
            reason: nil
        ))
    }

    @Test
    func `given a project that is no longer listed when it is located then nothing happens`() async {
        // given — the sheet and the list are read at different moments, and a project removed in
        // between is one this cannot move.
        let scenario = Scenario(projects: [], folderContents: [:], worktreesWithChanges: [:])

        // when
        await scenario.sut.relocateProject(
            id: ProjectID(canonicalPath: "/never-added"),
            to: URL(filePath: "/somewhere")
        )

        // then
        #expect(scenario.sut.projects.isEmpty)
        #expect(scenario.sut.projectsFailure == nil)
    }

    @Test
    func `given a scan sheet is up when it is dismissed then nothing is added`() async {
        // given
        let scenario = Scenario(
            projects: [],
            folderContents: [:],
            worktreesWithChanges: [:],
            candidates: [RepositoryCandidate(path: "/dev/one", name: "one", relativePath: "one")]
        )
        await scenario.sut.scanForRepositories(under: URL(filePath: "/dev"))

        // when
        scenario.sut.dismissFolderScan()

        // then — results never enter the list uninvited, and closing the sheet is the invitation
        // being declined.
        #expect(scenario.sut.folderScan == nil)
        #expect(scenario.sut.projects.isEmpty)
    }

    @Test
    func `given the store refuses when scanned repositories are added then it stops at the first`(
    ) async {
        // given — a store that will not write will not write the second one either, and thirty
        // identical failures is thirty writes nobody asked for after the answer was known.
        let scenario = Scenario(
            projects: [],
            folderContents: [:],
            worktreesWithChanges: [:],
            storeFailure: .notWritable(reason: "Read-only file system")
        )

        // when
        await scenario.sut.addScannedProjects([
            RepositoryCandidate(path: "/dev/one", name: "one", relativePath: "one"),
            RepositoryCandidate(path: "/dev/two", name: "two", relativePath: "two")
        ])

        // then
        #expect(scenario.sut.projects.isEmpty)
        #expect(scenario.sut.projectsFailure?.reason == "Read-only file system")
    }

    @Test
    func `given a folder scan when its results are chosen then they arrive added and switched off`(
    ) async {
        // given — "thirty found, none enabled" has to read as deliberate, so what the sheet writes
        // is added-and-off and the switch in the list is a second, separate act.
        let scenario = Scenario(
            projects: [],
            folderContents: ["/dev/one": .worktrees(count: 1), "/dev/two": .worktrees(count: 1)],
            worktreesWithChanges: [:]
        )

        // when
        await scenario.sut.addScannedProjects([
            RepositoryCandidate(path: "/dev/one", name: "one", relativePath: "one"),
            RepositoryCandidate(path: "/dev/two", name: "two", relativePath: "two")
        ])

        // then
        #expect(scenario.sut.projects.map(\.name) == ["one", "two"])
        #expect(scenario.sut.projects.allSatisfy { $0.isVisible == false })
    }

    @Test
    func `given a folder to scan when scanning then the sheet says it is looking before it answers`(
    ) async {
        // given
        let scenario = Scenario(
            projects: [],
            folderContents: [:],
            worktreesWithChanges: [:],
            candidates: [RepositoryCandidate(path: "/dev/one", name: "one", relativePath: "one")]
        )

        // when
        await scenario.sut.scanForRepositories(under: URL(filePath: "/dev"))

        // then
        #expect(scenario.sut.folderScan == .found(
            root: URL(filePath: "/dev"),
            candidates: [RepositoryCandidate(path: "/dev/one", name: "one", relativePath: "one")]
        ))
    }

    @Test
    func `given repositories already in the list when a folder is scanned then they are not offered again`(
    ) async {
        // given — the sheet's own subtitle says none of what it shows is added yet, and it has to
        // stay true. A candidate a reader already added is a checkbox that does nothing.
        let scenario = Scenario(
            projects: [storedProject(named: "dev/one")],
            folderContents: ["/dev/one": .worktrees(count: 1)],
            worktreesWithChanges: [:],
            candidates: [
                RepositoryCandidate(path: "/dev/one", name: "one", relativePath: "one"),
                RepositoryCandidate(path: "/dev/two", name: "two", relativePath: "two")
            ]
        )
        await scenario.sut.loadProjects()

        // when
        await scenario.sut.scanForRepositories(under: URL(filePath: "/dev"))

        // then
        guard case .found(_, let offered) = scenario.sut.folderScan else {
            Issue.record("expected a finished scan, got \(String(describing: scenario.sut.folderScan))")
            return
        }
        #expect(offered.map(\.name) == ["two"])
    }

    // MARK: - The lock on the document, SPEC §9

    @Test
    func `given another process holds the document when the app starts then it says so and names it`(
    ) async {
        // given — the second process to start refuses, and Advanced is where the refusal is read.
        let holder = StoreLockHolder(processIdentifier: 4213, processName: "granita-server")
        let scenario = Scenario(states: [.blockedByAnotherProcess(holder)])

        // when
        await scenario.sut.followServer()

        // then
        #expect(scenario.sut.serverState == .blockedByAnotherProcess(holder))
        #expect(scenario.sut.isBlockedByAnotherProcess)
        #expect(scenario.sut.storeLockHolder == holder)
    }

    @Test
    func `given the holder could not be read when the app is blocked then the row still appears`(
    ) async {
        // given — the lock is the kernel's answer and the name is a courtesy read from a file
        // beside it. A row drawn only when there is a name would disappear in exactly the case a
        // reader has least to go on.
        let scenario = Scenario(states: [.blockedByAnotherProcess(nil)])

        // when
        await scenario.sut.followServer()

        // then
        #expect(scenario.sut.isBlockedByAnotherProcess)
        #expect(scenario.sut.storeLockHolder == nil)
    }

    @Test
    func `given the server is serving normally when Advanced is drawn then no lock holder is claimed`(
    ) async {
        // given — the row is the only one on the tab describing a state in which the rest of the
        // app is doing nothing, so it must be absent whenever the app is doing something.
        let scenario = Scenario(states: [.running(ServerEndpoint(host: "MacBook-Pro.local", port: 59_144))])

        // when
        await scenario.sut.followServer()

        // then
        #expect(scenario.sut.isBlockedByAnotherProcess == false)
        #expect(scenario.sut.storeLockHolder == nil)
    }

    @Test
    func `given the app is blocked when Quit is pressed then the app is asked to end`() async {
        // given — an `LSUIElement` app has no Dock icon and no window whose red button ends it, so
        // without this the instruction "quit it and open Granita again" names something a reader
        // has no way to do from the screen telling them to do it.
        let scenario = Scenario(states: [.blockedByAnotherProcess(nil)])

        // when
        await scenario.sut.quit()

        // then
        #expect(await scenario.gestures.quits == 1)
    }

    // MARK: - Open in Console, which is two gestures because Console takes no URL

    @Test
    func `given the reader wants the log when Console is opened then the filter goes on the pasteboard`(
    ) async {
        // given — `Console.app` registers no URL scheme and cannot be handed a predicate, which is
        // why this is a copy and an open rather than one link. Settled 22 August 2026.
        let scenario = Scenario()

        // when
        await scenario.sut.openLogInConsole()

        // then — spelled out rather than rebuilt from the same expression the subject uses. A test
        // that recomputes the answer cannot see the answer change, and a filter spelled a second
        // way is a Console window that opens on nothing.
        #expect(await scenario.gestures.copied == ["subsystem == \"dev.fardavide.granita\""])
    }

    @Test
    func `given the reader wants the log when Console is opened then Console is what opens`() async {
        // given — the half that makes it a control rather than a silent pasteboard change: a
        // reader who presses this and sees nothing appear has met a dead control, whatever ended
        // up on the clipboard.
        let scenario = Scenario()

        // when
        await scenario.sut.openLogInConsole()

        // then
        #expect(await scenario.gestures.consoleOpenings == 1)
    }

    // MARK: - The gestures that used to be AppKit calls inside a view body

    @Test
    func `given a repository is picked when adding from the picker then it is added switched off`(
    ) async {
        // given — the whole flow, driven end to end. It used to start in a view body with an
        // `NSOpenPanel`, which is why every branch of it was uncovered: a view cannot be asked what
        // it did with the answer.
        let scenario = Scenario(
            projects: [],
            folderContents: ["/picked": .worktrees(count: 1)],
            worktreesWithChanges: [:],
            pickedFolder: URL(filePath: "/picked", directoryHint: .isDirectory)
        )

        // when
        await scenario.sut.addProjectFromPicker()

        // then
        #expect(scenario.sut.projects.map(\.name) == ["picked"])
        #expect(scenario.sut.projects[0].isVisible == false)
    }

    @Test
    func `given the reader changes their mind when adding from the picker then nothing happens`(
    ) async {
        // given — a cancelled pick is not an event. Nothing happened, and nothing on this tab
        // should move because somebody thought better of it.
        let scenario = Scenario(projects: [], folderContents: [:], worktreesWithChanges: [:])

        // when
        await scenario.sut.addProjectFromPicker()

        // then
        #expect(scenario.sut.projects.isEmpty)
        #expect(scenario.sut.projectsFailure == nil)
    }

    @Test
    func `given a folder is picked when scanning from the picker then the sheet opens on it`() async {
        // given
        let scenario = Scenario(
            projects: [],
            folderContents: [:],
            worktreesWithChanges: [:],
            candidates: [RepositoryCandidate(path: "/dev/one", name: "one", relativePath: "one")],
            pickedFolder: URL(filePath: "/dev", directoryHint: .isDirectory)
        )

        // when
        await scenario.sut.scanFolderFromPicker()

        // then
        guard case .found(_, let offered) = scenario.sut.folderScan else {
            Issue.record("expected a finished scan, got \(String(describing: scenario.sut.folderScan))")
            return
        }
        #expect(offered.map(\.name) == ["one"])
    }

    @Test
    func `given a cancelled pick when scanning then no sheet opens`() async {
        // given
        let scenario = Scenario(projects: [], folderContents: [:], worktreesWithChanges: [:])

        // when
        await scenario.sut.scanFolderFromPicker()

        // then — a sheet that opened empty because somebody cancelled a folder picker would be a
        // second thing to dismiss for no reason.
        #expect(scenario.sut.folderScan == nil)
    }

    @Test
    func `given a folder is picked when locating a project then it moves there`() async {
        // given
        let scenario = Scenario(
            projects: [StoredProject(
                id: ProjectID(canonicalPath: "/old/aura"),
                path: "/old/aura",
                name: "aura",
                isVisible: true
            )],
            folderContents: ["/old/aura": .folderNotFound, "/new/aura": .worktrees(count: 3)],
            worktreesWithChanges: [:],
            pickedFolder: URL(filePath: "/new/aura", directoryHint: .isDirectory)
        )
        await scenario.sut.loadProjects()

        // when
        await scenario.sut.locateProjectFromPicker(id: ProjectID(canonicalPath: "/old/aura"))

        // then
        #expect(scenario.sut.projects[0].path == "/new/aura")
    }

    @Test
    func `given the server is up when the address is copied then it reaches the pasteboard`() async {
        // given — the assertion that could not be made while this was an `NSPasteboard` call in a
        // view: whether the string a reader gets is the one the row shows.
        let scenario = Scenario(
            states: [.running(ServerEndpoint(host: "MacBook-Pro.local", port: 59_144))]
        )
        await scenario.sut.followServer()

        // when
        await scenario.sut.copyAddress()

        // then — host and port and nothing in front of them, which is General's own call: a scheme
        // would have to be `https` under a self-signed identity, and pasting that into a browser
        // produces a certificate warning rather than an answer.
        #expect(await scenario.gestures.copied == ["MacBook-Pro.local:59144"])
    }

    @Test
    func `given the server is not up when the address is copied then nothing is put on the pasteboard`(
    ) async {
        // given — the row draws an em dash in this state, and copying one would be worse than
        // copying nothing.
        let scenario = Scenario(states: [.failed(reason: "the local network is blocked")])
        await scenario.sut.followServer()

        // when
        await scenario.sut.copyAddress()

        // then
        #expect(await scenario.gestures.copied.isEmpty)
    }

    @Test
    func `when the data folder is revealed then Finder is pointed at the folder in use`() async {
        // given — and the folder in use is what `--store` moved it to, not the default one.
        let scenario = Scenario()

        // when
        await scenario.sut.revealDataFolder()

        // then
        #expect(await scenario.gestures.revealed == [scenario.sut.dataFolderUrl])
    }

    @Test
    func `when Local Network settings are asked for then that is the pane opened`() async {
        // given
        let scenario = Scenario()

        // when
        await scenario.sut.openSystemSettings(.localNetwork)

        // then
        #expect(await scenario.gestures.opened == [.localNetwork])
    }

    // MARK: - Locate, which is a move rather than an edit

    @Test
    func `given a project whose folder moved when it is located then it is the same project elsewhere`(
    ) async {
        // given — an identifier is a hash of a path, so a folder that moved is a different project
        // to everything that resolves one. What has to survive is the name and the switch.
        let scenario = Scenario(
            projects: [StoredProject(
                id: ProjectID(canonicalPath: "/old/aura"),
                path: "/old/aura",
                name: "aura",
                isVisible: true
            )],
            folderContents: ["/old/aura": .folderNotFound, "/new/aura": .worktrees(count: 3)],
            worktreesWithChanges: ["/new/aura": 1]
        )
        await scenario.sut.loadProjects()

        // when
        await scenario.sut.relocateProject(
            id: ProjectID(canonicalPath: "/old/aura"),
            to: URL(filePath: "/new/aura")
        )

        // then
        #expect(scenario.sut.projects.count == 1)
        #expect(scenario.sut.projects[0].name == "aura")
        #expect(scenario.sut.projects[0].path == "/new/aura")
        #expect(scenario.sut.projects[0].isVisible)
        #expect(scenario.sut.projects[0].contents == .worktrees(count: 3))
    }

    @Test
    func `given a folder that is not a repository when a project is located to it then nothing moves`(
    ) async {
        // given
        let scenario = Scenario(
            projects: [StoredProject(
                id: ProjectID(canonicalPath: "/old/aura"),
                path: "/old/aura",
                name: "aura",
                isVisible: true
            )],
            folderContents: ["/old/aura": .folderNotFound, "/downloads": .notARepository],
            worktreesWithChanges: [:]
        )
        await scenario.sut.loadProjects()

        // when
        await scenario.sut.relocateProject(
            id: ProjectID(canonicalPath: "/old/aura"),
            to: URL(filePath: "/downloads")
        )

        // then — losing the last known path to a mis-aimed pick would take away the one thing that
        // says which project this row is.
        #expect(scenario.sut.projects[0].path == "/old/aura")
        #expect(scenario.sut.projectsFailure == StoreWriteFailure(
            sentence: "That folder is not a git repository.",
            reason: nil
        ))
    }

    // MARK: - Which pane is up

    @Test
    func `given this Mac has never opened the window when it is drawn then Projects is the pane in front`() {
        // given - when — a first run, which is what remembering nothing means.
        let scenario = Scenario(lastUsedTab: nil)

        // then — design §2, and the reason is not symmetry with the tab order: until a repository is
        // switched on the app does nothing at all, so General would open on an address no phone can
        // use yet.
        #expect(scenario.sut.settingsTab == .projects)
    }

    @Test
    func `given a pane was up last time when the window is drawn then that pane is in front`() {
        // given - when
        let scenario = Scenario(lastUsedTab: .connections)

        // then
        #expect(scenario.sut.settingsTab == .connections)
    }

    @Test
    func `given a pane is brought to the front when it is shown then the next launch opens on it`() {
        // given
        let scenario = Scenario(lastUsedTab: .general)

        // when
        scenario.sut.showSettingsTab(.advanced)

        // then
        #expect(scenario.memory.remembered == [.advanced])
    }

    @Test
    func `given a refusal offering to pair when it is taken up then Devices comes to the front`() {
        // given — the whole of what `Pair…` does. Held on the model rather than in the window's own
        // state, because a control whose only effect is a `@State` two layers up is a control
        // nothing can be asked about, and this app shipped one of those for eight releases.
        let scenario = Scenario()

        // when
        scenario.sut.showSettingsTab(.devices)

        // then
        #expect(scenario.sut.settingsTab == .devices)
    }

    // MARK: - Devices, and the code that adds one

    @Test
    func `given the server is serving when Devices is opened then it offers a code for that address`() async {
        // given
        let endpoint = ServerEndpoint(host: "MacBook-Pro.local", port: 59_144)
        let scenario = Scenario(states: [.running(endpoint)])
        await scenario.sut.followServer()

        // when
        await scenario.sut.offerPairing()

        // then — a link naming an address this Mac is not reachable at pairs a phone that then
        // fails every connection afterwards, with nothing on either side saying why.
        guard case .offered(let invitation) = scenario.sut.pairingOffer else {
            Issue.record("expected a code, got \(scenario.sut.pairingOffer)")
            return
        }
        #expect(invitation.link.host == "MacBook-Pro.local")
        #expect(invitation.link.port == 59_144)
        #expect(scenario.invitations.lastEndpoint == endpoint)
    }

    @Test
    func `given a live code when the words are copied then the pasteboard reads as the tab shows them`() async {
        // given
        let scenario = Scenario(states: [.running(ServerEndpoint(host: "MacBook-Pro.local", port: 59_144))])
        await scenario.sut.followServer()
        await scenario.sut.offerPairing()

        // when
        await scenario.sut.copySpokenCode()

        // then — the line as drawn, middle dots and all. The words *are* the credential, so a
        // clipboard spelling them differently from the line above it would be refused by the phone
        // with a reason that names the code rather than the punctuation.
        #expect(await scenario.gestures.copied == ["delta · pepper · amber · kelp · jasper · meadow"])
    }

    @Test
    func `given a code that has run out when the words are copied then nothing is put on the pasteboard`() async {
        // given — the words are not drawn in this state, so the button is not there to press. What
        // this holds is the other half: a credential lives two minutes, and "the button is absent"
        // and "this will not hand a reader something spent" are one re-evaluation apart.
        let scenario = Scenario(
            states: [.running(ServerEndpoint(host: "MacBook-Pro.local", port: 59_144))],
            codeExpiresAt: Date(timeIntervalSince1970: 120),
            now: Date(timeIntervalSince1970: 300)
        )
        await scenario.sut.followServer()
        await scenario.sut.offerPairing()

        // when
        await scenario.sut.copySpokenCode()

        // then
        #expect(await scenario.gestures.copied.isEmpty)
    }

    @Test
    func `given nothing is serving when the words are copied then nothing is put on the pasteboard`() async {
        // given — there is no code at all here, and the pane says pairing needs the server.
        let scenario = Scenario(states: [.failed(reason: "the local network is blocked")])
        await scenario.sut.followServer()
        await scenario.sut.offerPairing()

        // when
        await scenario.sut.copySpokenCode()

        // then
        #expect(await scenario.gestures.copied.isEmpty)
    }

    @Test
    func `given the server is still binding when Devices is opened then it says a code is being made`() async {
        // given — a bind takes a moment and a rebind after waking takes longer. "Nothing is serving"
        // during it sends a reader holding a phone to General to fix something already happening.
        let scenario = Scenario(states: [.starting])
        await scenario.sut.followServer()

        // when
        await scenario.sut.offerPairing()

        // then
        #expect(scenario.sut.pairingOffer == .preparing)
        #expect(scenario.invitations.invitations == 0)
    }

    @Test
    func `given nothing is serving when Devices is opened then it says pairing needs the server`() async {
        // given
        let scenario = Scenario(states: [.failed(reason: "the local network is blocked")])
        await scenario.sut.followServer()

        // when
        await scenario.sut.offerPairing()

        // then — and no code was spent producing a link to nowhere.
        #expect(scenario.sut.pairingOffer == .serverNotRunning)
        #expect(scenario.invitations.invitations == 0)
    }

    @Test
    func `given the identity cannot be read when Devices is opened then it says so in the keychain's words`() async {
        // given — the code is signed by an identity out of the login keychain, which can be locked.
        let scenario = Scenario(
            states: [.running(ServerEndpoint(host: "MacBook-Pro.local", port: 59_144))],
            pairingFailure: .noIdentity(reason: "unlock the login keychain")
        )
        await scenario.sut.followServer()

        // when
        await scenario.sut.offerPairing()

        // then
        #expect(scenario.sut.pairingOffer == .unavailable(reason: "unlock the login keychain"))
    }

    @Test
    func `given a code is on screen when a new one is asked for then a second code is spent`() async {
        // given
        let scenario = Scenario(states: [.running(ServerEndpoint(host: "MacBook-Pro.local", port: 59_144))])
        await scenario.sut.followServer()
        await scenario.sut.offerPairing()

        // when
        await scenario.sut.offerPairing()

        // then — *New Code* has to reach the actor holding the outstanding offers, not redraw the
        // one already on screen: an expired code redraws identically and stays refused.
        #expect(scenario.invitations.invitations == 2)
        guard case .offered(let invitation) = scenario.sut.pairingOffer else {
            Issue.record("expected a code, got \(scenario.sut.pairingOffer)")
            return
        }
        #expect(invitation.link.code == "code-2")
    }

    @Test
    func `given a device this run has served when Devices is drawn then its row says when`() async {
        // given
        let served = Date(timeIntervalSince1970: 900)
        let scenario = Scenario(
            readings: [[ConnectionAttempt(
                id: UUID(),
                at: served,
                source: "192.168.1.42",
                outcome: .accepted(device: "Davide's iPhone", id: "Davide's iPhone"),
                occurrences: 18
            )]],
            devices: [storedDevice(named: "Davide's iPhone")]
        )

        // when
        await scenario.sut.loadDevices()
        await scenario.sut.followConnections()

        // then
        #expect(scenario.sut.devices.map(\.sighting) == [.seen(at: served)])
    }

    @Test
    func `given a device nothing has been heard from when Devices is drawn then its row says how far back this run goes`(
    ) async {
        // given — the log is in memory, so "not seen" is only ever a claim about this run of the
        // app. A date from the store would read as an accusation the data cannot support.
        let launched = Date(timeIntervalSince1970: 500)
        let scenario = Scenario(devices: [storedDevice(named: "iPad Pro")], now: launched)

        // when
        await scenario.sut.loadDevices()

        // then
        #expect(scenario.sut.devices.map(\.sighting) == [.notSeenSince(launched)])
    }

    @Test
    func `given two devices when only one has connected then the sighting lands on that one`() async {
        // given — the log carries the identifier beside the name for exactly this: a reader with two
        // phones called the same thing would otherwise see one row's sighting on both.
        let served = Date(timeIntervalSince1970: 900)
        let scenario = Scenario(
            readings: [[ConnectionAttempt(
                id: UUID(),
                at: served,
                source: "192.168.1.42",
                outcome: .accepted(device: "renamed since", id: "iPad Pro"),
                occurrences: 4
            )]],
            devices: [storedDevice(named: "Davide's iPhone"), storedDevice(named: "iPad Pro")],
            now: Date(timeIntervalSince1970: 500)
        )

        // when
        await scenario.sut.loadDevices()
        await scenario.sut.followConnections()

        // then
        #expect(scenario.sut.devices.map(\.sighting) == [
            .notSeenSince(Date(timeIntervalSince1970: 500)),
            .seen(at: served)
        ])
    }

    @Test
    func `given a paired device when it is revoked then it is gone from the list`() async {
        // given
        let scenario = Scenario(devices: [storedDevice(named: "Davide's iPhone"), storedDevice(named: "iPad Pro")])
        await scenario.sut.loadDevices()

        // when
        await scenario.sut.revokeDevice(id: "iPad Pro")

        // then
        #expect(scenario.sut.devices.map(\.name) == ["Davide's iPhone"])
        #expect(scenario.sut.devicesFailure == nil)
    }

    @Test
    func `given the store refuses when a device is revoked then the row stays and the tab says why`() async {
        // given — a Revoke that leaves the row where it was and says nothing is a control that did
        // nothing, on the one tab where doing nothing means a phone can still read this Mac.
        let scenario = Scenario(
            devices: [storedDevice(named: "Davide's iPhone")],
            storeFailure: .notWritable(reason: "No space left on device")
        )
        await scenario.sut.loadDevices()

        // when
        await scenario.sut.revokeDevice(id: "Davide's iPhone")

        // then
        #expect(scenario.sut.devices.map(\.name) == ["Davide's iPhone"])
        #expect(scenario.sut.devicesFailure == StoreWriteFailure(
            sentence: "That change could not be saved.",
            reason: "No space left on device"
        ))
    }

    @Test
    func `given Devices refused a write when Projects is used then the refusal stays on Devices`() async {
        // given — two tabs write to one document, and a Projects failure drawn under the device list
        // sends a reader looking in the wrong place for something that did not happen there.
        let scenario = Scenario(
            projects: [storedProject(named: "aura")],
            devices: [storedDevice(named: "Davide's iPhone")],
            folderContents: ["/aura": .worktrees(count: 2)],
            storeFailure: .documentIsFromANewerVersion
        )

        // when
        await scenario.sut.revokeDevice(id: "Davide's iPhone")

        // then
        #expect(scenario.sut.devicesFailure != nil)
        #expect(scenario.sut.projectsFailure == nil)
    }
}

// MARK: -

private struct Scenario {

    let sut: ServerMacModel
    let loginItems: FakeLoginItemRegistry
    let restarts: FakeServerRestarting
    let store: FakeStore
    let folders: FakeProjectFolders
    let picker: FakeFolderPicking
    let gestures: FakeSystemGestures
    let invitations: FakePairingInviting
    let memory: FakeSettingsTabMemory
    let verbosity: FakeVerboseLogging

    init(
        states: [ServerRunState] = [],
        readings: [[ConnectionAttempt]] = [],
        opensAtLogin: Bool = false,
        loginItemFailure: LoginItemFailure? = nil,
        git: GitInstallation = .checking,
        projects: [StoredProject] = [],
        devices: [StoredDevice] = [],
        folderContents: [String: ProjectContents] = [:],
        worktreesWithChanges: [String: Int] = [:],
        candidates: [RepositoryCandidate] = [],
        pickedFolder: URL? = nil,
        storeFailure: StoreError? = nil,
        pairingFailure: PairingInvitationError? = nil,
        codeExpiresAt: Date = Date(timeIntervalSince1970: 120),
        lastUsedTab: SettingsTab? = .general,
        isVerbose: Bool = false,
        now: Date = Date(timeIntervalSince1970: 0)
    ) {
        loginItems = FakeLoginItemRegistry(isRegistered: opensAtLogin, failure: loginItemFailure)
        restarts = FakeServerRestarting()
        store = FakeStore(projects: projects, devices: devices, failure: storeFailure)
        folders = FakeProjectFolders(
            contents: folderContents,
            worktreesWithChanges: worktreesWithChanges,
            candidates: candidates
        )
        picker = FakeFolderPicking(folder: pickedFolder)
        gestures = FakeSystemGestures()
        invitations = FakePairingInviting(failure: pairingFailure, expiresAt: codeExpiresAt)
        memory = FakeSettingsTabMemory(stored: lastUsedTab)
        verbosity = FakeVerboseLogging(isVerbose: isVerbose)
        sut = ServerMacModel(
            host: FakeServerHost(states: states),
            restarts: restarts,
            connectionLog: FakeConnectionLog(readings: readings),
            loginItems: loginItems,
            gitInstallations: FakeGitInstallations(installation: git),
            projectFolders: folders,
            folderPicker: picker,
            gestures: gestures,
            store: store,
            invitations: invitations,
            tabMemory: memory,
            verboseLogging: verbosity,
            dataFolderUrl: URL(filePath: "/Users/davide/Library/Application Support/Granita"),
            now: { now }
        )
    }
}

private func storedProject(named name: String, isVisible: Bool = true) -> StoredProject {
    StoredProject(
        id: ProjectID(canonicalPath: "/\(name)"),
        path: "/\(name)",
        name: (name as NSString).lastPathComponent,
        isVisible: isVisible
    )
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
