import Foundation
import Observation

import CoreDiffDomain
import ServerApiDomain
import ServerMacDomain
import ServerStoreDomain

/// What the Mac app knows, in one place.
///
/// One model for the unit rather than one per screen. The menu bar item and the Settings window are
/// two views onto the same running server, and a state object per view splits that server's state
/// across as many objects as there are places it is drawn — which is a slice per view, not a layer.
/// Views stay stateless and are handed values; this is the only thing between them and the
/// protocols the `Domain` declares.
@Observable
public final class ServerMacModel {

    /// Starting rather than stopped, because the app launches the server as it launches itself.
    /// A menu bar item exists only while that is happening, so "not serving" would be a state this
    /// says before it is true.
    public private(set) var serverState: ServerRunState = .starting

    /// When the server last bound, which is not the same as when the app launched — a rebind after
    /// a wake or a Restart moves it, and that is the point. `nil` until something has bound in this
    /// run of the app; General reads it only in the branch that has already established the server
    /// is running.
    public private(set) var servingSince: Date?

    public private(set) var connectionAttempts: [ConnectionAttempt] = []

    /// Off until the system has been asked. General reads it when it opens rather than trusting
    /// this initial value, which is a placeholder and not a claim.
    public private(set) var loginItem: LoginItemState = .off

    /// Which git this Mac would run. `.checking` until Advanced has opened and asked, because
    /// asking runs a subprocess.
    public private(set) var gitInstallation: GitInstallation = .checking

    /// Every project a reader added, switched on or not, with what this Mac can still find behind
    /// each. The API's own project list is not this: it describes what is switched **on**, because
    /// that is all a phone is ever told about.
    public private(set) var projects: [ManagedProject] = []

    /// What a folder scan turned up, for as long as the sheet showing it is up.
    ///
    /// Design §4: results never enter the list uninvited. This is where they wait instead, and the
    /// only way out of it is a reader choosing.
    public private(set) var folderScan: FolderScan?

    /// Which of a scan's results are ticked, by path.
    ///
    /// Beside ``folderScan`` rather than inside the sheet, for the same reason that is here: both
    /// belong to one act a reader is halfway through, and both die when it ends. It also makes the
    /// count in the confirm button something a test can assert rather than something only a finger
    /// can produce.
    public private(set) var chosenCandidatePaths: Set<String> = []

    /// Why the last thing Projects tried to write did not happen, in the store's own words.
    ///
    /// Not drawn by the frames, and built anyway. Every control on that tab writes to the store, and
    /// a switch that springs back with no explanation is a control that did nothing.
    public private(set) var projectsFailure: StoreWriteFailure?

    /// The same, for Devices. Its one write is `Revoke`, and a Revoke that leaves the row where it
    /// was is the same defect wearing different clothes.
    public private(set) var devicesFailure: StoreWriteFailure?

    /// Which pane of the Settings window is up.
    ///
    /// Here rather than in the window's own `@State`, because it is not only the tab bar that moves
    /// it: a refused connection offers `Pair…`, whose whole job is to bring the reader to the QR.
    /// A control whose only effect is a `@State` two layers up is a control nothing can be asked
    /// about — and this app has already shipped one of those for eight releases.
    ///
    /// General on launch. Design §2 wants **Projects** on a first run, which needs the window to
    /// know what a first run is; that lands with §1's half of the same section.
    public private(set) var settingsTab: SettingsTab = .general

    /// What the Devices tab can offer a phone right now.
    ///
    /// `.preparing` until something has asked, which is honest rather than a placeholder: making a
    /// code reads the identity out of the Keychain, so there is a real moment before there is one.
    public private(set) var pairingOffer: PairingOffer = .preparing

    /// Every phone that has paired, with what this run of the app has heard from it.
    ///
    /// Derived rather than stored, so a device that connects while the tab is open stops saying it
    /// has not been seen without anything having to notice. The stored half is what the document
    /// holds; the sighting is read off the connection log, which is the only thing that knows.
    public var devices: [PairedDevice] {
        pairedDevices.map { device in
            PairedDevice(
                id: device.id,
                name: device.name,
                platform: device.platform,
                pairedAt: device.pairedAt,
                // Newest first, so the first match is the latest sighting.
                sighting: connectionAttempts.first { $0.outcome.deviceId == device.id }
                    .map { .seen(at: $0.at) } ?? .notSeenSince(startedAt)
            )
        }
    }

    /// What a reset would destroy, counted from the store rather than guessed.
    ///
    /// Two numbers rather than the whole state: this tab counts what exists in order to make one
    /// sentence proportionate to one button, and holding a copy of everything the store knows in
    /// order to say "two" would be a second source of truth for the thing that is the security
    /// boundary.
    public private(set) var storedProjectCount = 0
    public private(set) var storedDeviceCount = 0

    /// Where the document lives, for the row that reveals it. A fact rather than a lookup: the
    /// composition root already had to know it in order to open the store.
    public let dataFolderUrl: URL

    /// When this run of the app began watching, which is as far back as anything it can say about a
    /// device goes. The connection log is in memory, so a phone last served yesterday and a phone
    /// never served at all are indistinguishable from here — and the row says so rather than
    /// implying the first.
    private let startedAt: Date

    private let host: any ServerHosting
    private let restarts: any ServerRestarting
    private let connectionLog: any ConnectionLog
    private let loginItems: any LoginItemRegistry
    private let gitInstallations: any GitInstallations
    private let projectFolders: any ProjectFolders
    private let folderPicker: any FolderPicking
    private let gestures: any SystemGestures
    private let store: any Store
    private let invitations: any PairingInviting
    private let now: @Sendable () -> Date
    private var pairedDevices: [StoredDevice] = []

    public init(
        host: any ServerHosting,
        restarts: any ServerRestarting,
        connectionLog: any ConnectionLog,
        loginItems: any LoginItemRegistry,
        gitInstallations: any GitInstallations,
        projectFolders: any ProjectFolders,
        folderPicker: any FolderPicking,
        gestures: any SystemGestures,
        store: any Store,
        invitations: any PairingInviting,
        dataFolderUrl: URL,
        now: @escaping @Sendable () -> Date
    ) {
        self.host = host
        self.restarts = restarts
        self.connectionLog = connectionLog
        self.loginItems = loginItems
        self.gitInstallations = gitInstallations
        self.projectFolders = projectFolders
        self.folderPicker = folderPicker
        self.gestures = gestures
        self.store = store
        self.invitations = invitations
        self.dataFolderUrl = dataFolderUrl
        self.now = now
        startedAt = now()
    }

    /// Follows the server for as long as the app is running.
    public func followServer() async {
        for await state in host.run() {
            // Stamped on the transition rather than on every reading, so a server that stays up
            // keeps saying when it came up. A rebind moves it, which is the whole reason General
            // shows the time at all: it is how "this has been fine all morning" is told apart from
            // "this has just stood itself up again while I was not looking".
            let wasRunning = if case .running = serverState { true } else { false }
            if case .running = state, wasRunning == false {
                servingSince = now()
            }
            serverState = state
        }
    }

    /// Stands the server up again, at the reader's request.
    public func restartServer() async {
        await restarts.restart()
    }

    /// Follows the connection log for as long as the panel that draws it is on screen. The attempt
    /// worth seeing is usually the one that has not happened yet when it is opened.
    public func followConnections() async {
        for await reading in await connectionLog.attempts() {
            connectionAttempts = reading
        }
    }

    /// Runs the git that was found, which is the only way to learn whether it works.
    public func loadGitInstallation() async {
        gitInstallation = await gitInstallations.current()
    }

    // MARK: - The gestures a pane performs on the system around it

    /// Puts this Mac's address where a `curl` can be pasted, which is the one real use for it.
    ///
    /// Reads the endpoint here rather than taking a string from the view, so the copy and the row
    /// cannot spell it differently — and copies nothing at all when there is nothing to copy, which
    /// is the state the row draws an em dash in.
    public func copyAddress() async {
        guard case .running(let endpoint) = serverState else { return }
        await gestures.copyToPasteboard("\(endpoint.host):\(endpoint.port)")
    }

    /// Finder, pointed at the document actually in use rather than at where it usually lives.
    public func revealDataFolder() async {
        await gestures.revealInFinder(dataFolderUrl)
    }

    public func openSystemSettings(_ pane: SystemSettingsPane) async {
        await gestures.openSystemSettings(pane)
    }

    // MARK: - Projects

    /// Reads the list, draws it, and only then goes and finds out what has changed inside it.
    ///
    /// **Two passes because there are two prices, and Davide chose to pay the second one in the
    /// background rather than to drop the figure it buys.** The worktree count is one git invocation
    /// per project; the count of worktrees with uncommitted work is one *per worktree*, measured on
    /// 23 August 2026 at 16.7 seconds for a single Android monorepo's sixteen. A tab that waited for
    /// the second number is a tab that does not open.
    public func loadProjects() async {
        let stored = await store.state().projects
        var loaded: [ManagedProject] = []
        for project in stored {
            loaded.append(ManagedProject(
                id: project.id,
                name: project.name,
                path: project.path,
                isVisible: project.isVisible,
                contents: await projectFolders.contents(ofFolderAt: project.path),
                worktreesWithChanges: .counting
            ))
        }
        projects = loaded
        await countWorktreesWithChanges()
    }

    /// Switches a project on or off, which is the only control on this tab with consequences.
    public func setProjectVisible(_ isVisible: Bool, id: ProjectID) async {
        projectsFailure = await write { () async throws(StoreError) in
            try await store.setProjectVisible(isVisible, id: id)
        }
        guard projectsFailure == nil else { return }
        await loadProjects()
    }

    /// Forgets a project. Not the same as switching it off, and the plus/minus bar keeps them apart.
    public func removeProject(id: ProjectID) async {
        projectsFailure = await write { () async throws(StoreError) in try await store.removeProject(id: id) }
        guard projectsFailure == nil else { return }
        await loadProjects()
    }

    /// Adds one folder a reader picked by hand, switched off.
    ///
    /// The picker will offer any folder on this Mac, so this is the one add that checks. A row
    /// reading "not a repository" for something chosen a second ago says less than refusing does.
    public func addProject(atFolder folder: URL) async {
        let path = Self.canonicalPath(of: folder)
        switch await projectFolders.contents(ofFolderAt: path) {
        case .worktrees:
            projectsFailure = await write { () async throws(StoreError) in
                try await store.add(project: Self.project(atPath: path))
            }
            guard projectsFailure == nil else { return }
            await loadProjects()
        case .folderNotFound:
            projectsFailure = StoreWriteFailure(sentence: "That folder is not there any more.", reason: nil)
        case .notARepository:
            projectsFailure = StoreWriteFailure(sentence: "That folder is not a git repository.", reason: nil)
        }
    }

    /// Adds what a scan turned up and a reader chose, every one of them switched off.
    ///
    /// No check, and that is the difference from the picker above: a candidate is a folder this Mac
    /// found a `.git` directory in a moment ago, so asking git again would be one subprocess per
    /// chosen repository to learn something already known.
    public func addScannedProjects(_ candidates: [RepositoryCandidate]) async {
        folderScan = nil
        chosenCandidatePaths = []
        for candidate in candidates {
            projectsFailure = await write { () async throws(StoreError) in
                try await store.add(project: Self.project(atPath: candidate.path))
            }
            guard projectsFailure == nil else { break }
        }
        await loadProjects()
    }

    /// Points a project at the folder it moved to.
    ///
    /// A remove and an add rather than an edit, because an identifier is a hash of a path: to
    /// everything that resolves one, a folder that moved is a different project. What survives is
    /// the name and the switch, which are the two things a reader decided.
    public func relocateProject(id: ProjectID, to folder: URL) async {
        guard let existing = projects.first(where: { $0.id == id }) else { return }
        let path = Self.canonicalPath(of: folder)
        guard case .worktrees = await projectFolders.contents(ofFolderAt: path) else {
            projectsFailure = StoreWriteFailure(sentence: "That folder is not a git repository.", reason: nil)
            return
        }
        let moved = StoredProject(
            id: ProjectID(canonicalPath: path),
            path: path,
            name: existing.name,
            isVisible: existing.isVisible
        )
        projectsFailure = await write { () async throws(StoreError) in
            try await store.removeProject(id: id)
            try await store.add(project: moved)
        }
        guard projectsFailure == nil else { return }
        await loadProjects()
    }

    /// Asks for a repository and adds it.
    ///
    /// **This flow used to begin in a view body with an `NSOpenPanel`, and that was the defect.**
    /// A pick decides — a folder, or a reader who changed their mind — and a decision taken inside a
    /// `body` is one no test can supply either side of. Here it is three lines a fake can drive.
    public func addProjectFromPicker() async {
        guard let folder = await folderPicker.pickFolder(
            prompt: "Add",
            message: "Choose a git repository to add. It arrives switched off."
        ) else { return }
        await addProject(atFolder: folder)
    }

    /// Asks for a folder and looks inside it.
    public func scanFolderFromPicker() async {
        // Cleared before the pick rather than after it, so a second scan never opens carrying the
        // previous one's ticks against a different folder's list.
        chosenCandidatePaths = []
        guard let folder = await folderPicker.pickFolder(
            prompt: "Scan",
            message: "Choose a folder to look for git repositories in. Nothing is added yet."
        ) else { return }
        await scanForRepositories(under: folder)
    }

    /// Asks where a project went, and moves it there.
    public func locateProjectFromPicker(id: ProjectID) async {
        guard let folder = await folderPicker.pickFolder(
            prompt: "Locate",
            message: "Choose where this repository is now."
        ) else { return }
        await relocateProject(id: id, to: folder)
    }

    /// Looks for repositories under a folder, and puts what it finds in front of a reader rather
    /// than into the list.
    public func scanForRepositories(under root: URL) async {
        folderScan = .scanning(root: root)
        let known = Set(projects.map(\.path))
        let found = await projectFolders.repositories(under: root)
        // Already-added repositories are not offered, which is what keeps the sheet's own subtitle
        // true: it says none of what it shows is added yet, and a checkbox for something already in
        // the list is a control with nothing behind it.
        folderScan = .found(root: root, candidates: found.filter { known.contains($0.path) == false })
    }

    /// What the sheet's checkboxes wrote back.
    public func setChosenCandidatePaths(_ paths: Set<String>) {
        chosenCandidatePaths = paths
    }

    public func dismissFolderScan() {
        folderScan = nil
        chosenCandidatePaths = []
    }

    /// Counts what has changed, project by project, into a list that is already on screen.
    ///
    /// Asked only of the projects whose figure is drawn — a switched-off row says "not visible" and
    /// has nowhere to put a count — and each answer lands on its own rather than at the end, so the
    /// first project's figure appears while the last one is still being read.
    private func countWorktreesWithChanges() async {
        for project in projects where project.isVisible {
            guard case .worktrees = project.contents else { continue }
            let dirty = await projectFolders.worktreesWithChanges(inFolderAt: project.path)
            // The reader left the tab, or the list was reloaded under this loop by a switch they
            // flipped while it ran. Either way this answer is about a list that is gone.
            guard Task.isCancelled == false else { return }
            guard let index = projects.firstIndex(where: { $0.id == project.id }) else { continue }
            projects[index].worktreesWithChanges = .counted(dirty)
        }
    }

    /// Runs one write and answers with whatever the store refused it with, or nothing.
    ///
    /// The answer goes to the tab that asked rather than into one shared property, because two tabs
    /// write to this document and a Projects refusal appearing under the Devices list would send a
    /// reader looking in the wrong place. Callers re-read their list only when this is `nil`:
    /// re-reading after a refusal draws the same rows twice for no reason.
    private func write(_ mutation: () async throws(StoreError) -> Void) async -> StoreWriteFailure? {
        do {
            try await mutation()
            return nil
        } catch {
            return switch error {
            case .notWritable(let reason):
                StoreWriteFailure(sentence: "That change could not be saved.", reason: reason)
            case .documentIsFromANewerVersion:
                StoreWriteFailure(
                    sentence: "A newer version of Granita wrote this Mac's settings, so they were left alone.",
                    reason: nil
                )
            }
        }
    }

    /// A new project is always switched off. Adding a repository and letting a phone read it are
    /// two separate acts, and this is the end of the first one.
    private static func project(atPath path: String) -> StoredProject {
        StoredProject(
            id: ProjectID(canonicalPath: path),
            path: path,
            name: (path as NSString).lastPathComponent,
            isVisible: false
        )
    }

    /// No trailing separator, because a project's identifier is a hash of this string and the same
    /// folder spelled two ways is two projects that cannot both be switched on.
    private static func canonicalPath(of folder: URL) -> String {
        var path = folder.standardizedFileURL.path(percentEncoded: false)
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }

    /// Brings a pane to the front, whether a reader clicked the tab bar or pressed something that
    /// leads here.
    public func showSettingsTab(_ tab: SettingsTab) {
        settingsTab = tab
    }

    // MARK: - Devices

    /// Reads the phones this Mac has paired with.
    public func loadDevices() async {
        pairedDevices = await store.state().devices
    }

    /// Makes a pairing a phone can redeem, against the address this Mac is actually reachable at.
    ///
    /// Asked for again whenever the server's state moves, which is what makes *server not running*
    /// a state the tab arrives in rather than one it has to be told about — and what puts a working
    /// code up the moment a rebind succeeds under a reader who is standing there with a phone.
    ///
    /// **A live code is left up until its replacement lands.** Going back through `.preparing` on
    /// every ask would blink the QR at the one moment somebody is pointing a camera at it.
    public func offerPairing() async {
        guard case .running(let endpoint) = serverState else {
            pairingOffer = .serverNotRunning
            return
        }
        do {
            pairingOffer = .offered(try await invitations.invite(at: endpoint))
        } catch {
            pairingOffer = switch error {
            case .noIdentity(let reason): .unavailable(reason: reason)
            }
        }
    }

    /// Forgets a device, so its token stops working.
    ///
    /// The phone is not told, and cannot be: it holds the only copy of a token this Mac no longer
    /// recognises, so what it meets next is a refusal — which is why the connection log's
    /// *Token not issued by this Mac* row carries a `Pair Again…` and is the other half of this.
    public func revokeDevice(id: String) async {
        devicesFailure = await write { () async throws(StoreError) in try await store.removeDevice(id: id) }
        guard devicesFailure == nil else { return }
        await loadDevices()
    }

    // MARK: - Advanced

    /// Counts what a reset would destroy.
    public func loadStoredCounts() async {
        let state = await store.state()
        storedProjectCount = state.projects.count
        storedDeviceCount = state.devices.count
    }

    /// Forgets everything, at the reader's request and after a confirmation that counted it.
    ///
    /// A refusal is swallowed rather than surfaced, and that is a decision rather than an
    /// oversight: the counts are **re-read** afterwards, so a reset that could not be written
    /// leaves the sentence above the button describing what is still there. A tab that said "no
    /// projects" over a full disk would be lying about the one thing here that matters.
    public func resetAllData() async {
        try? await store.reset()
        await loadStoredCounts()
    }

    /// Asks the system where the login item actually stands, which is the only place that knows.
    public func loadLoginItem() async {
        loginItem = await loginItems.isRegistered() ? .on : .off
    }

    /// A refusal is a third state rather than a thrown error, because the caller is a `Toggle` and
    /// there is nothing for it to do with one — what it needs is to draw itself off and say why.
    public func setLoginItem(enabled: Bool) async {
        do {
            if enabled {
                try await loginItems.register()
            } else {
                try await loginItems.unregister()
            }
            loginItem = enabled ? .on : .off
        } catch {
            switch error {
            case .notApproved: loginItem = .awaitingApproval
            case .refused(let reason): loginItem = .refused(reason: reason)
            }
        }
    }
}
