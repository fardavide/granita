import Foundation
import Hummingbird
import HummingbirdTesting

import CoreBrandingDomain
import CoreDiffDomain
import ServerApiDomain
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
    let connectionLog: InMemoryConnectionLog
    let diagnostics: FakeDiagnostics
    let location: RepositoryLocation

    /// Which checkouts git has been run in, for the one question a response body cannot answer:
    /// how much of this Mac a request read before it answered.
    let git: RecordingGitClient

    init(repository: FixtureRepository, requiresAuthentication: Bool = false) throws {
        try self.init(at: try repository.location(), requiresAuthentication: requiresAuthentication)
    }

    init(at location: RepositoryLocation, requiresAuthentication: Bool = false) throws {
        storeDirectory = URL.temporaryDirectory
            .appending(path: "granita-api-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        store = JsonDocumentStore(
            fileUrl: storeDirectory.appending(path: "granita.json", directoryHint: .notDirectory)
        )

        git = RecordingGitClient(ProcessGitClient(
            executablePath: "/usr/bin/git",
            outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
            timeout: ProcessGitClient.defaultTimeout
        ))
        let service = WorktreeService(git: git, limits: .standard)

        pairing = Pairing(store: store, now: { Date() })
        connectionLog = InMemoryConnectionLog(now: { Date() })
        // Unfiltered, deliberately: what the middleware records is this suite's question, and
        // whether the verbose switch would have suppressed it is `VerbosityFilteringDiagnostics`'s.
        diagnostics = FakeDiagnostics()
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
            connectionLog: connectionLog,
            diagnostics: diagnostics,
            serverVersion: "0.0.4",
            // A runner's interface list is not ours to assert on, and no test here reads this.
            wakeAddresses: [],
            requiresAuthentication: requiresAuthentication
        )
        application = Application(router: GranitaRouter.build(dependencies))
        self.location = location
    }

    /// What the Advanced panel would be showing, newest attempt first.
    func recordedAttempts() async -> [ConnectionAttempt] {
        var readings = await connectionLog.attempts().makeAsyncIterator()
        return await readings.next() ?? []
    }

    /// Enables the fixture repository, the way `--add-project` does.
    func enableProject() async throws {
        try await enableProject(at: location)
    }

    /// Enables a second repository, for the questions that only have an answer when this Mac is
    /// serving more than one — which is what a Mac Granita is worth running on looks like.
    func enableProject(at location: RepositoryLocation) async throws {
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

/// A repository built for one test and thrown away with it.
///
/// **The committed fixtures are shared and one route now deletes a worktree.** Driving that against
/// them would take a checkout out from under everything else that reads them, and the suite
/// asserting the main fixture has three worktrees is where it would surface — a run later, in a test
/// that changed nothing. `make fixtures` would put it back, which means the second run of an
/// unchanged tree behaves differently from the first, and that is worse than a slow test.
///
/// It is the real binary against a real repository like every other test here; only the ownership is
/// different.
struct DisposableRepository {

    /// The primary checkout, which is what a project points at.
    let location: RepositoryLocation

    /// The linked worktree, with uncommitted work in it, which is what a test deletes.
    let worktree: RepositoryLocation

    let branch = "agent-slice"

    private let root: URL

    init() throws {
        root = URL.temporaryDirectory
            .appending(path: "granita-disposable-\(UUID().uuidString)", directoryHint: .isDirectory)
        let checkout = root.appending(path: "project", directoryHint: .notDirectory)
        let linked = root.appending(path: "worktree", directoryHint: .notDirectory)
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)

        try Self.git(["init", "--quiet", "--initial-branch=main"], in: checkout)
        try Self.git(["config", "user.email", "fixture@granita.test"], in: checkout)
        try Self.git(["config", "user.name", "Granita Fixture"], in: checkout)
        try Self.git(["commit", "--quiet", "--allow-empty", "-m", "first"], in: checkout)
        try Self.git(["worktree", "add", "--quiet", "-b", branch, linked.path(percentEncoded: false)], in: checkout)

        // Uncommitted, because that is the only kind of worktree this list ever offers: without it
        // `worktree remove` would succeed unforced and the test would prove nothing about `--force`.
        try Data("work in progress\n".utf8).write(
            to: linked.appending(path: "wip.txt", directoryHint: .notDirectory)
        )

        // **Read back from git rather than computed here**, because an identifier is a hash of this
        // exact string and two plausible spellings of one directory hash differently. A `URL` for a
        // directory carries a trailing separator that git never emits, and `resolvingSymlinksInPath`
        // leaves `/var/folders` alone on macOS where git reports `/private/var/folders` — either one
        // produces an identifier matching nothing, and every route then answers `worktreeGone` about
        // a worktree sitting right there. Git lists the main worktree first.
        let listed = try Self.worktreePaths(in: checkout)
        guard listed.count == 2 else { throw FixtureSetupFailed(command: "worktree list", exitCode: 0) }
        location = RepositoryLocation(path: listed[0])
        worktree = RepositoryLocation(path: listed[1])
    }

    /// Marks the worktree as one git will not remove under a single `--force`, which is what Claude
    /// Code does to every worktree it creates.
    func lockTheWorktree() throws {
        try Self.git(["worktree", "lock", worktree.path], in: URL(filePath: location.path))
    }

    /// Takes write permission off the directory holding the worktree, so git can see it and cannot
    /// unlink it.
    ///
    /// The one way found to make `worktree remove --force --force` fail for a reason that is **not**
    /// the one the route predicts — which is the arm that hands git's own sentence to the phone, and
    /// the only kind of removal failure a reader could be told anything useful about.
    func makeTheWorktreeUndeletable() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path())
    }

    /// Whether the branch the worktree was on is still in the repository.
    func hasBranch(_ name: String) throws -> Bool {
        try Self.output(["branch", "--list", "--format=%(refname:short)"], in: URL(filePath: location.path))
            .split(separator: "\n")
            .contains(name[...])
    }

    /// What `git worktree list` says now, one absolute path per checkout, main worktree first.
    func worktreePaths() throws -> [String] {
        try Self.worktreePaths(in: URL(filePath: location.path))
    }

    /// Puts the write permission back before deleting, or the test that took it away leaves the
    /// directory behind on every run.
    func cleanUp() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path())
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private static func git(_ arguments: [String], in directory: URL) throws -> String {
        try output(arguments, in: directory)
    }

    private static func worktreePaths(in directory: URL) throws -> [String] {
        try output(["worktree", "list", "--porcelain"], in: directory)
            .split(separator: "\n")
            .filter { $0.hasPrefix("worktree ") }
            .map { String($0.dropFirst("worktree ".count)) }
    }

    private static func output(_ arguments: [String], in directory: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FixtureSetupFailed(command: arguments.joined(separator: " "), exitCode: process.terminationStatus)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

struct FixtureSetupFailed: Error, CustomStringConvertible {
    let command: String
    let exitCode: Int32
    var description: String { "git \(command) exited \(exitCode) while building a disposable repository" }
}

extension ApiScenario {

    /// Just enough to answer `/v1/health`, for the tests that are only about that route.
    ///
    /// Health is the one endpoint that answers before anything is set up — before pairing, before a
    /// project is enabled, before there is anything to read — so a fixture for it should not need
    /// any of that either.
    static func healthOnlyDependencies(serverVersion: String, wakeAddresses: [String] = []) -> ApiDependencies {
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
            connectionLog: InMemoryConnectionLog(now: { Date() }),
            diagnostics: FakeDiagnostics(),
            serverVersion: serverVersion,
            wakeAddresses: wakeAddresses,
            requiresAuthentication: false
        )
    }
}
