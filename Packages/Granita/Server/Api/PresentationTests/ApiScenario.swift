import Foundation
import Hummingbird
import HummingbirdTesting

import CoreBrandingDomain
import CoreDiffDomain
import ServerApiPresentation
import ServerGitData
import ServerGitDomain
import ServerSessionsData
import ServerStoreData
import ServerStoreDomain
import ServerWorktreesDomain

/// The whole server, wired the way the executable wires it, over a real fixture repository.
///
/// Nothing is faked below the router: the git client runs the real binary, the store writes a real
/// document, and the change sets are whatever git says about repositories `make fixtures` built.
/// SPEC §12 asks M2 to be proven that way, and the traps this milestone exists to survive —
/// renames, conflicts, an unborn HEAD — only exist in real output.
struct ApiScenario {

    let application: any ApplicationProtocol
    let store: JsonDocumentStore
    let storeDirectory: URL
    let pairing: Pairing
    let location: RepositoryLocation

    init(repository: FixtureRepository, requiresAuthentication: Bool = false) throws {
        storeDirectory = URL.temporaryDirectory
            .appending(path: "granita-api-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        store = JsonDocumentStore(
            fileUrl: storeDirectory.appending(path: "granita.json", directoryHint: .notDirectory)
        )

        let git = ProcessGitClient(
            executablePath: "/usr/bin/git",
            outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
            timeout: ProcessGitClient.defaultTimeout
        )
        let service = WorktreeService(git: git, limits: .standard)
        let location = try repository.location()

        pairing = Pairing(store: store, now: { Date() })
        let dependencies = ApiDependencies(
            registry: WorktreeRegistry(
                store: store,
                service: service,
                // The session index reads the developer's own `~/.claude`, which is neither
                // present nor predictable on a runner. Suggested names are best effort by design,
                // so the seam is closed here with none rather than with someone's real transcripts.
                suggestedAliases: { _ in [:] }
            ),
            service: service,
            store: store,
            pairing: pairing,
            failedAttempts: FailedAttempts(now: { Date() }),
            serverVersion: "0.0.4",
            requiresAuthentication: requiresAuthentication
        )
        application = Application(router: GranitaRouter.build(dependencies))
        self.location = location
    }

    /// Enables the fixture repository, the way `--add-project` does.
    func enableProject() async throws {
        try await store.add(project: StoredProject(
            id: ProjectID(canonicalPath: location.path),
            path: location.path,
            name: (location.path as NSString).lastPathComponent,
            isVisible: true
        ))
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: storeDirectory)
    }
}

/// One of the repositories `make fixtures` builds. Gitignored and absent from a fresh checkout, so
/// the failure says what to run rather than reading as a broken test.
enum FixtureRepository: String {
    case main
    case unborn
    case conflicted
    case renames

    func location() throws -> RepositoryLocation {
        var directory = URL(filePath: #filePath).deletingLastPathComponent()
        while directory.path(percentEncoded: false) != "/" {
            let candidate = directory.appending(path: ".fixtures", directoryHint: .isDirectory)
            if FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
                let repository = candidate.appending(path: rawValue, directoryHint: .notDirectory)
                return RepositoryLocation(
                    path: repository.resolvingSymlinksInPath().path(percentEncoded: false)
                )
            }
            directory = directory.deletingLastPathComponent()
        }
        throw MissingFixtures()
    }
}

struct MissingFixtures: Error, CustomStringConvertible {
    var description: String {
        "the git fixture repositories are absent from this checkout — run `make fixtures`"
    }
}

extension ApiScenario {

    /// Just enough to answer `/v1/health`, for the tests that are only about that route.
    ///
    /// Health is the one endpoint that answers before anything is set up — before pairing, before a
    /// project is enabled, before there is anything to read — so a fixture for it should not need
    /// any of that either.
    static func healthOnlyDependencies(serverVersion: String) -> ApiDependencies {
        let store = JsonDocumentStore(
            fileUrl: URL.temporaryDirectory
                .appending(path: "granita-health-\(UUID().uuidString)", directoryHint: .isDirectory)
                .appending(path: "granita.json", directoryHint: .notDirectory)
        )
        let service = WorktreeService(
            git: ProcessGitClient(
                executablePath: "/usr/bin/git",
                outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
                timeout: ProcessGitClient.defaultTimeout
            ),
            limits: .standard
        )
        return ApiDependencies(
            registry: WorktreeRegistry(store: store, service: service, suggestedAliases: { _ in [:] }),
            service: service,
            store: store,
            pairing: Pairing(store: store, now: { Date() }),
            failedAttempts: FailedAttempts(now: { Date() }),
            serverVersion: serverVersion,
            requiresAuthentication: false
        )
    }
}
