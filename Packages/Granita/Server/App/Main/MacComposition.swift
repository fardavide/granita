import Foundation
import Observation

import CoreBrandingDomain
import CorePairingDomain
import ServerApiDomain
import ServerApiPresentation
import ServerGitData
import ServerIdentityData
import ServerIdentityDomain
import ServerMacData
import ServerMacDomain
import ServerMacPresentation
import ServerSessionsData
import ServerStoreData
import ServerStoreDomain
import ServerWorktreesDomain

/// Everything the menu bar app is made of, wired once.
///
/// The Mac app embeds the same backend `granita-server` runs, so this is deliberately the same
/// assembly as the executable's — the shape is copied, not the code, because the two differ in
/// exactly two places: this one never offers the plaintext escape hatch, and it hands the server's
/// states to a view model instead of to a terminal.
@Observable
@MainActor
final class MacComposition {

    let model: ServerMacModel

    /// Bumped when the menu asks for Settings. The window that can actually open it watches this;
    /// see `SettingsOpener` for why it cannot simply be a call.
    private(set) var settingsRequests = 0

    /// Whether the app was told to put Settings on screen without waiting for the menu.
    let opensSettingsAtLaunch: Bool

    init(launch: MacLaunchOptions) {
        opensSettingsAtLaunch = launch.opensSettingsAtLaunch
        // The one thing about this app a launch argument may move, and it moves for one reason: a
        // behavioural test drives the real app, and the real app with no seam here would switch a
        // real repository on in the reader's own document and leave it that way.
        let storeUrl = launch.storeUrl ?? Self.defaultStoreUrl
        let store = JsonDocumentStore(fileUrl: storeUrl)
        // A path with no binary at it surfaces as git being unavailable, with git's own words,
        // which is the failure the Advanced panel is there to show. Kept in a `let` because that
        // panel prints it beside the version it got by running it.
        let gitPath = GitExecutablePath.firstAvailable(among: GitExecutablePath.defaultCandidates)
            ?? "/usr/bin/git"
        let git = ProcessGitClient(
            executablePath: gitPath,
            outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
            timeout: ProcessGitClient.defaultTimeout
        )
        let service = WorktreeService(git: git, limits: .standard)
        let sessions = SessionIndex(rootUrl: SessionIndex.defaultRootUrl())
        let log = InMemoryConnectionLog(now: { Date() })
        let pairing = Pairing(store: store, now: { Date() })

        // Generated on first run and kept for ten years. The addresses are read once, here: a
        // certificate that chased the current ones would change its key every time the Mac joined
        // a network, and its key is what every paired phone is pinning.
        let identities = KeychainServerIdentityStore(subject: .thisMac, now: { Date() })

        let dependencies = ApiDependencies(
            registry: WorktreeRegistry(
                store: store,
                service: service,
                suggestedAliases: { worktrees in await sessions.suggestedAliases(for: worktrees) }
            ),
            service: service,
            store: store,
            pairing: pairing,
            failedAttempts: FailedAttempts(now: { Date() }),
            connectionLog: log,
            serverVersion: Branding.serverVersion,
            // The plaintext escape hatch is a flag on the executable and is never reachable from
            // here. A token over plaintext is a token everyone on the network already has.
            requiresAuthentication: true
        )

        // The Mac woke, or someone pressed Restart. One stream, because what a rebind *does* is
        // identical either way and the teardown ordering is delicate enough to want one owner.
        let rebinds = Rebinds(wakes: WorkspaceWakeNotifications())

        model = ServerMacModel(
            // Wrapped rather than replaced: waking is the only thing this adds, and everything
            // about how the server binds stays in one place.
            host: RebindingOnWake(
                host: TransportResolvingServerHost(
                    dependencies: dependencies,
                    binding: .bonjourService(name: MachineName.computer),
                    // Asked per run, not once here. A rebind after waking has to be able to fail
                    // for a reason someone can act on — a locked keychain, an identity deleted by
                    // hand — and a transport resolved at launch could only report that as the app
                    // never having started.
                    transport: { () async throws(ServerIdentityError) -> ApiTransport in
                        .tls(try await identities.keychainIdentity().reference)
                    }
                ),
                wakes: rebinds
            ),
            restarts: rebinds,
            connectionLog: log,
            loginItems: ServiceLoginItemRegistry(),
            gitInstallations: ProcessGitInstallations(git: git, executablePath: gitPath),
            projectFolders: FileSystemProjectFolders(service: service),
            folderPicker: AppKitFolderPicker(),
            gestures: AppKitSystemGestures(),
            store: store,
            invitations: PairingInvitations(pairing: pairing, identities: identities),
            tabMemory: UserDefaultsSettingsTabMemory(defaults: .standard),
            dataFolderUrl: storeUrl.deletingLastPathComponent(),
            now: { Date() }
        )

        // The server's life is the app's life, not a window's: a `.task` on any view would tie
        // serving to something SwiftUI is free to tear down.
        Task { [model] in await model.followServer() }
        // Followed from launch rather than from the Connections tab opening, because two tabs read
        // it now: a device row's *Seen 4 min ago* comes from this log, and a reader who has never
        // opened Connections would otherwise be told every phone they own has not been seen.
        Task { [model] in await model.followConnections() }
        Task { await sessions.refresh() }
    }

    /// Puts the Settings window on screen, on a particular pane when the caller has one in mind.
    ///
    /// **The pane is applied here and does not travel on `settingsRequests`**, which is a departure
    /// from what design §1 expected and from what `decisions.md` predicted, and the reason is that
    /// the model has since become the owner of which pane is up. A pane riding on the request would
    /// be a second copy of that fact — and `SettingsOpener` watches this value with `onChange`, which
    /// cannot tell "asked for Devices again" from "nothing happened", so a reader who moved to
    /// Advanced and pressed *Pair a device…* a second time would land on a menu item that did
    /// nothing. The counter stays a counter because what it signals is "open", and opening twice is
    /// two events.
    ///
    /// Ordered rather than incidental: the pane is set before the window is asked for, so the window
    /// opens already showing it instead of arriving on one pane and moving.
    func requestSettings(showing tab: SettingsTab?) {
        if let tab {
            model.showSettingsTab(tab)
        }
        settingsRequests += 1
    }

    /// The same document the executable reads, so the two cannot disagree about what is enabled.
    ///
    /// Where it lives when nothing said otherwise. `--store` moves it, and Advanced's data-folder
    /// row reads whichever one is actually in use rather than this one.
    ///
    /// SPEC §9 also wants a lock file beside it, so a standalone `granita-server` and this app
    /// cannot both hold it. That is not here yet.
    private static var defaultStoreUrl: URL {
        URL(filePath: NSHomeDirectory())
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
            .appending(path: Branding.applicationSupportDirectoryName, directoryHint: .isDirectory)
            .appending(path: "granita.json", directoryHint: .notDirectory)
    }
}
