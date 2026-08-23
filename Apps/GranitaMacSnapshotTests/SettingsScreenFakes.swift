import Foundation

import CoreDiffDomain
import ServerApiDomain
import ServerMacDomain
import ServerMacPresentation
import ServerStoreDomain

/// The seven doubles `ServerMacModel` needs, so the whole Settings window can be rendered.
///
/// **These live in the snapshot bundle rather than being shared with the package suite, and they
/// have to.** SwiftPM test targets cannot import each other, and the alternative — a fixtures module
/// shipped in the product so both can see it — puts test doubles in the binary a reader installs.
/// The cost is this file; the thing it buys is that `GranitaSettingsScreen` is rendered by something
/// at all. Until it was, the screen that composes every tab was in the views scope and in no
/// baseline, which is both a coverage hole and, more to the point, a tab bar nobody had ever looked
/// at a picture of.
enum SettingsScreenFakes {

    /// A model that is not running anything, wired to answer every question the window asks.
    @MainActor
    static func model(
        state: ServerRunState,
        attempts: [ConnectionAttempt],
        git: GitInstallation,
        projects: Int,
        devices: Int
    ) -> ServerMacModel {
        ServerMacModel(
            host: FakeHost(state: state),
            restarts: FakeRestarts(),
            connectionLog: FakeLog(reading: attempts),
            loginItems: FakeLoginItems(),
            gitInstallations: FakeGitInstallations(installation: git),
            projectFolders: FakeProjectFolders(),
            store: FakeStore(projects: projects, devices: devices),
            dataFolderUrl: URL(filePath: NSHomeDirectory())
                .appending(path: "Library/Application Support/Granita", directoryHint: .isDirectory),
            now: { Date(timeIntervalSince1970: 1_755_864_000) }
        )
    }

    /// Everything the composition root and the panes' `.task` modifiers would have done.
    ///
    /// A hosted view runs no `.task`, and the screen never starts the server itself, so a model
    /// rendered straight after construction reports its initial values whatever it was handed.
    /// Each of these fakes yields once and finishes, so none of them hangs the render.
    @MainActor
    static func drive(_ model: ServerMacModel) async {
        await model.followServer()
        await model.followConnections()
        await model.loadLoginItem()
        await model.loadGitInstallation()
        await model.loadStoredCounts()
        await model.loadProjects()
    }
}

// MARK: -

/// Yields once and finishes, so `followServer` settles rather than holding the render open.
private struct FakeHost: ServerHosting {

    let state: ServerRunState

    func run() -> AsyncStream<ServerRunState> {
        AsyncStream { continuation in
            continuation.yield(state)
            continuation.finish()
        }
    }
}

private struct FakeRestarts: ServerRestarting {
    func restart() async {}
}

private struct FakeLog: ConnectionLog {

    /// Named for the reading rather than for the protocol's accessor, which is a method of the same
    /// name and cannot be shadowed by a stored property.
    let reading: [ConnectionAttempt]

    func record(source: String, outcome: ConnectionOutcome) async {}

    func attempts() -> AsyncStream<[ConnectionAttempt]> {
        AsyncStream { continuation in
            continuation.yield(reading)
            continuation.finish()
        }
    }
}

private struct FakeLoginItems: LoginItemRegistry {
    func isRegistered() async -> Bool { true }
    func register() throws(LoginItemFailure) {}
    func unregister() throws(LoginItemFailure) {}
}

private struct FakeGitInstallations: GitInstallations {

    let installation: GitInstallation

    func current() async -> GitInstallation { installation }
}

/// Every project the window's fake store holds is a folder with two worktrees, one of them dirty.
///
/// A fixed answer rather than a configurable one: the window's own baselines are about the tab bar
/// and the pane inside it, and `ProjectsSettingsView` has baselines of its own for the states of a
/// row.
private struct FakeProjectFolders: ProjectFolders {

    func contents(ofFolderAt path: String) -> ProjectContents { .worktrees(count: 2) }
    func worktreesWithChanges(inFolderAt path: String) -> Int { 1 }
    func repositories(under root: URL) -> [RepositoryCandidate] { [] }
}

private actor FakeStore: Store {

    private var stored: StoredState

    init(projects: Int, devices: Int) {
        stored = StoredState(
            projects: (0..<projects).map {
                StoredProject(
                    id: ProjectID(canonicalPath: "/p\($0)"), path: "/p\($0)", name: "p\($0)", isVisible: true
                )
            },
            worktrees: [:],
            viewed: [:],
            devices: (0..<devices).map {
                StoredDevice(
                    id: "d\($0)", name: "d\($0)", platform: "iOS",
                    tokenHash: "h\($0)", pairedAt: Date(timeIntervalSince1970: 1)
                )
            }
        )
    }

    func state() -> StoredState { stored }
    func reset() throws(StoreError) { stored = .empty }

    func add(project: StoredProject) throws(StoreError) {}
    func setProjectVisible(_ isVisible: Bool, id: ProjectID) throws(StoreError) {}
    func removeProject(id: ProjectID) throws(StoreError) {}
    func setAlias(_ alias: String?, for worktree: WorktreeID) throws(StoreError) {}
    func setPinned(_ isPinned: Bool, for worktree: WorktreeID) throws(StoreError) {}
    func setViewed(_ isViewed: Bool, file: FileID, contentHash: String) throws(StoreError) {}
    func add(device: StoredDevice) throws(StoreError) {}
    func removeDevice(id: String) throws(StoreError) {}
}
