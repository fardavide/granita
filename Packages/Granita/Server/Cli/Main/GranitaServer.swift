import Foundation

import CoreBrandingDomain
import CoreDiagnosticsData
import CoreDiagnosticsDomain
import CoreDiffDomain
import CorePairingDomain
import ServerApiDomain
import ServerApiPresentation
import ServerGitData
import ServerGitDomain
import ServerIdentityData
import ServerIdentityDomain
import ServerSessionsData
import ServerStoreData
import ServerStoreDomain
import ServerWorktreesDomain

/// Composition root for the terminal. The menu bar app embeds the same backend in-process; this
/// executable is what makes it build, run and test with `swift run` and `swift test` with no Xcode
/// in the loop — and what recovers a review session when the UI is the thing that is broken.
@main
struct GranitaServer {

    static func main() async {
        let arguments = Arguments(CommandLine.arguments.dropFirst())
        if arguments.wantsHelp {
            print(Arguments.usage)
            return
        }

        let store = JsonDocumentStore(fileUrl: arguments.storeUrl)
        let git = LoggingGitClient(
            client: ProcessGitClient(
                executablePath: gitExecutablePath(),
                outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
                timeout: ProcessGitClient.defaultTimeout
            ),
            diagnostics: VerbosityFilteringDiagnostics(
                wrapped: OsLogDiagnostics(),
                verbosity: UserDefaultsVerboseLogging(defaults: .standard)
            )
        )
        let service = WorktreeService(git: git, limits: .standard)

        if let path = arguments.projectToAdd {
            await add(project: path, to: store, using: service)
            return
        }
        if arguments.wantsToken {
            await issueToken(from: store)
            return
        }

        let sessions = SessionIndex(rootUrl: SessionIndex.defaultRootUrl())
        await sessions.refresh()

        let pairing = Pairing(store: store, now: { Date() })
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
            // The terminal has stderr for this; the log is here because the menu bar app draws it
            // and both composition roots build the same dependencies.
            connectionLog: InMemoryConnectionLog(now: { Date() }),
            // The same subsystem the Mac app writes to, so one predicate reads either.
            //
            // **The same key, but not the same defaults domain, and that is worth knowing rather
            // than papering over.** An executable has no bundle identifier, so `UserDefaults`
            // resolves to the global domain here and to `dev.fardavide.granita.mac` in the app:
            // turning verbose on for one does not turn it on for the other. `defaults write -g` is
            // this one's switch, since a terminal already has a flag for everything else and a
            // second mechanism would be a second answer to one question.
            diagnostics: VerbosityFilteringDiagnostics(
                wrapped: OsLogDiagnostics(),
                verbosity: UserDefaultsVerboseLogging(defaults: .standard)
            ),
            serverVersion: Branding.serverVersion,
            // Plaintext means every token on the wire is already everyone's, so demanding one would
            // be theatre. The flag exists so a TLS problem can never leave code unreviewable, and
            // it is never reachable from the Mac app's UI.
            requiresAuthentication: arguments.isInsecureHttp == false
        )

        let binding: ApiServerBinding
        let transport: ApiTransport
        if arguments.isInsecureHttp {
            binding = .hostname("0.0.0.0", port: arguments.port)
            transport = .insecurePlaintext
            log("serving plain HTTP on 0.0.0.0:\(arguments.port) — no TLS, no Bonjour, no token required")
        } else {
            binding = .bonjourService(name: arguments.serviceName)
            do {
                transport = .tls(try await identities.keychainIdentity().reference)
            } catch {
                log("no TLS identity: \(error)")
                exit(1)
            }
            log("advertising \(Branding.bonjourServiceType) as \"\(arguments.serviceName)\"")
        }

        let projects = await store.state().projects
        log("\(projects.count) project(s) enabled\(projects.isEmpty ? " — add one with --add-project <path>" : "")")

        do {
            try await ApiServer.make(
                configuration: ApiServerConfiguration(
                    dependencies: dependencies,
                    binding: binding,
                    transport: transport
                )
            ) { endpoint in
                // With a Bonjour bind the port is the system's choice, so this is the first moment
                // anything knows it — and it is the number to curl.
                guard let endpoint else { return log("listening, but the port is not knowable") }
                log("listening on \(endpoint.host):\(endpoint.port)")
                if arguments.wantsPairing {
                    await offerPairing(
                        PairingInvitations(pairing: pairing, identities: identities),
                        at: endpoint
                    )
                }
            }
            .runService()
        } catch {
            log("stopped: \(error)")
            exit(1)
        }
    }

    /// Prints a pairing invitation, and keeps printing a fresh one as each expires.
    ///
    /// The Mac app will show a QR; there is no QR in a terminal, and there is no way to ask a
    /// running server for a code from outside it — the codes live in the actor serving requests.
    /// So `--pair` is how a device is paired without the menu bar app, which is what makes the TLS
    /// path exercisable before the pairing screen exists.
    ///
    /// Reissuing rather than printing once, because two minutes is not long enough to fumble a
    /// phone out of a pocket and a server that has to be restarted to hand out a second code is a
    /// worse debugging tool than one that repeats itself.
    private static func offerPairing(_ invitations: PairingInvitations, at endpoint: ServerEndpoint) async {
        Task {
            while Task.isCancelled == false {
                do {
                    let invitation = try await invitations.invite(at: endpoint)
                    log("pair with: \(invitation.link.text)")
                    log("  or type: \(invitation.spokenCode)")
                    log("  pinning: \(invitation.link.fingerprint.rawValue)")
                } catch {
                    log("could not offer a pairing: \(error)")
                    return
                }
                try? await Task.sleep(for: .seconds(Pairing.codeLifetime))
            }
        }
    }

    /// Enabling a project is deliberately a thing a person does at the Mac, by naming a path.
    /// It is the only place a path enters the system, and it is what every opaque identifier the
    /// API accepts is resolved against afterwards.
    private static func add(project path: String, to store: JsonDocumentStore, using service: WorktreeService) async {
        let canonical = URL(filePath: path).resolvingSymlinksInPath().path(percentEncoded: false)
        let location = RepositoryLocation(path: canonical)
        do {
            let root = try await service.worktrees(in: location)
            guard let primary = root.first else {
                log("\(canonical) is not a git repository")
                exit(1)
            }
            let repositoryRoot = primary.location.path
            try await store.add(project: StoredProject(
                id: ProjectID(canonicalPath: repositoryRoot),
                path: repositoryRoot,
                name: (repositoryRoot as NSString).lastPathComponent,
                isVisible: true
            ))
            log("enabled \(repositoryRoot) with \(root.count) worktree(s)")
        } catch {
            log("could not enable \(canonical): \(error)")
            exit(1)
        }
    }

    /// Pairs without a camera, for driving the API from a terminal.
    private static func issueToken(from store: JsonDocumentStore) async {
        let pairing = Pairing(store: store, now: { Date() })
        let offered = await pairing.invite()
        do {
            let response = try await pairing.redeem(
                code: offered.code,
                deviceName: "terminal",
                platform: "cli"
            )
            print(response.token)
        } catch {
            log("could not issue a token: \(error)")
            exit(1)
        }
    }

    /// Being wrong here is the one failure that makes every other part of this useless, so it is
    /// checked rather than assumed — and shared with the menu bar app, which must run the same one.
    private static func gitExecutablePath() -> String {
        guard let found = GitExecutablePath.firstAvailable(among: GitExecutablePath.defaultCandidates) else {
            log("no git binary found; tried \(GitExecutablePath.defaultCandidates.joined(separator: ", "))")
            return "/usr/bin/git"
        }
        return found
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("granita-server: \(message)\n".utf8))
    }
}

// MARK: -

/// Deliberately hand-rolled rather than pulling an argument parser in. The flag set is small and
/// fixed, and a dependency the product does not otherwise need is not worth a nicer `--help`.
private struct Arguments {

    let wantsHelp: Bool
    let isInsecureHttp: Bool
    let port: Int
    let serviceName: String
    let projectToAdd: String?
    let wantsToken: Bool
    let wantsPairing: Bool
    let storeUrl: URL

    static let usage = """
        granita-server — serves uncommitted worktree diffs over the local network.

          --add-project <path>  Enable a repository, then exit. The only way a path enters
                                the system; everything after this is addressed by identifier.
          --issue-token         Print a bearer token for driving the API by hand, then exit.
          --pair                Keep printing a granita://pair link and six-word code, so a
                                device can pair over TLS without the menu bar app.
          --insecure-http       Serve plain HTTP instead of advertising over Bonjour with TLS,
                                and require no token. Off by default, never reachable from the UI.
          --port <n>            Port for --insecure-http. Default \(Branding.defaultPort).
          --service-name <s>    Bonjour instance name. Defaults to this machine's name.
          --store <path>        Where the JSON document lives.
          --help                This.
        """

    init(_ arguments: some Sequence<String>) {
        let arguments = Array(arguments)
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        wantsHelp = arguments.contains("--help") || arguments.contains("-h")
        isInsecureHttp = arguments.contains("--insecure-http")
        port = value(after: "--port").flatMap(Int.init) ?? Branding.defaultPort
        serviceName = value(after: "--service-name") ?? MachineName.computer
        projectToAdd = value(after: "--add-project")
        wantsToken = arguments.contains("--issue-token")
        wantsPairing = arguments.contains("--pair")
        storeUrl = value(after: "--store").map { URL(filePath: $0) }
            ?? URL(filePath: NSHomeDirectory())
                .appending(path: "Library/Application Support", directoryHint: .isDirectory)
                .appending(path: Branding.applicationSupportDirectoryName, directoryHint: .isDirectory)
                .appending(path: "granita.json", directoryHint: .notDirectory)
    }
}
