import Foundation

import CoreBrandingDomain
import CoreDiffDomain
import ServerApiPresentation
import ServerGitData
import ServerGitDomain
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
        let git = ProcessGitClient(
            executablePath: gitExecutablePath(),
            outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
            timeout: ProcessGitClient.defaultTimeout
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
            // The terminal has stderr for this; the log is here because the menu bar app draws it
            // and both composition roots build the same dependencies.
            connectionLog: InMemoryConnectionLog(now: { Date() }),
            serverVersion: Branding.serverVersion,
            // Plaintext means every token on the wire is already everyone's, so demanding one would
            // be theatre. The flag exists so a TLS problem can never leave code unreviewable, and
            // it is never reachable from the Mac app's UI.
            requiresAuthentication: arguments.isInsecureHttp == false
        )

        let binding: ApiServerBinding = arguments.isInsecureHttp
            ? .hostname("0.0.0.0", port: arguments.port)
            : .bonjourService(name: arguments.serviceName)

        switch binding {
        case .hostname(let host, let port):
            log("serving plain HTTP on \(host):\(port) — no TLS, no Bonjour, no token required")
        case .bonjourService(let name):
            log("advertising \(Branding.bonjourServiceType) as \"\(name)\"")
        }

        let projects = await store.state().projects
        log("\(projects.count) project(s) enabled\(projects.isEmpty ? " — add one with --add-project <path>" : "")")

        do {
            try await ApiServer.make(
                configuration: ApiServerConfiguration(dependencies: dependencies, binding: binding)
            ).runService()
        } catch {
            log("stopped: \(error)")
            exit(1)
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
        let issued = await pairing.issueCode()
        do {
            let response = try await pairing.redeem(
                code: issued.code,
                deviceName: "terminal",
                platform: "cli"
            )
            print(response.token)
        } catch {
            log("could not issue a token: \(error)")
            exit(1)
        }
    }

    /// `/usr/bin/git` first, then whatever Xcode's tooling points at, then the path.
    ///
    /// The first is the shim every Mac has; the second is what a machine with the command line
    /// tools but no `/usr/bin/git` resolves to. Being wrong here is the one failure that makes
    /// every other part of this useless, so it is checked rather than assumed.
    private static func gitExecutablePath() -> String {
        let candidates = ["/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        log("no git binary found; tried \(candidates.joined(separator: ", "))")
        return "/usr/bin/git"
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
    let storeUrl: URL

    static let usage = """
        granita-server — serves uncommitted worktree diffs over the local network.

          --add-project <path>  Enable a repository, then exit. The only way a path enters
                                the system; everything after this is addressed by identifier.
          --issue-token         Print a bearer token for driving the API by hand, then exit.
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
        serviceName = value(after: "--service-name") ?? ProcessInfo.processInfo.hostName
        projectToAdd = value(after: "--add-project")
        wantsToken = arguments.contains("--issue-token")
        storeUrl = value(after: "--store").map { URL(filePath: $0) }
            ?? URL(filePath: NSHomeDirectory())
                .appending(path: "Library/Application Support", directoryHint: .isDirectory)
                .appending(path: Branding.applicationSupportDirectoryName, directoryHint: .isDirectory)
                .appending(path: "granita.json", directoryHint: .notDirectory)
    }
}
