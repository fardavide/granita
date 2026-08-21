import Foundation
import Observation

import CoreBrandingDomain
import ServerApiDomain
import ServerApiPresentation
import ServerGitData
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

    init() {
        let store = JsonDocumentStore(fileUrl: Self.storeUrl)
        let git = ProcessGitClient(
            executablePath: GitExecutablePath.firstAvailable(among: GitExecutablePath.defaultCandidates)
                // A path with no binary at it surfaces as git being unavailable, with git's own
                // words, which is the failure the Advanced panel is there to show.
                ?? "/usr/bin/git",
            outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
            timeout: ProcessGitClient.defaultTimeout
        )
        let service = WorktreeService(git: git, limits: .standard)
        let sessions = SessionIndex(rootUrl: SessionIndex.defaultRootUrl())
        let log = InMemoryConnectionLog(now: { Date() })

        let dependencies = ApiDependencies(
            registry: WorktreeRegistry(
                store: store,
                service: service,
                suggestedAliases: { worktrees in await sessions.suggestedAliases(for: worktrees) }
            ),
            service: service,
            store: store,
            pairing: Pairing(store: store, now: { Date() }),
            failedAttempts: FailedAttempts(now: { Date() }),
            connectionLog: log,
            serverVersion: Branding.serverVersion,
            // The plaintext escape hatch is a flag on the executable and is never reachable from
            // here. A token over plaintext is a token everyone on the network already has.
            requiresAuthentication: true
        )

        model = ServerMacModel(
            host: ApiServerHost(
                configuration: ApiServerConfiguration(
                    dependencies: dependencies,
                    binding: .bonjourService(name: MachineName.computer)
                )
            ),
            connectionLog: log
        )

        // The server's life is the app's life, not a window's: a `.task` on any view would tie
        // serving to something SwiftUI is free to tear down.
        Task { [model] in await model.followServer() }
        Task { await sessions.refresh() }
    }

    func requestSettings() {
        settingsRequests += 1
    }

    /// The same document the executable reads, so the two cannot disagree about what is enabled.
    ///
    /// SPEC §9 also wants a lock file beside it, so a standalone `granita-server` and this app
    /// cannot both hold it. That is not here yet.
    private static var storeUrl: URL {
        URL(filePath: NSHomeDirectory())
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
            .appending(path: Branding.applicationSupportDirectoryName, directoryHint: .isDirectory)
            .appending(path: "granita.json", directoryHint: .notDirectory)
    }
}
