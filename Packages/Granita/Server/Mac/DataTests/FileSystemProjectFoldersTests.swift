import Foundation
import Testing

import ServerGitDomain
import ServerMacDomain
import ServerWorktreesDomain
@testable import ServerMacData

/// What the Projects tab can still find on this Mac's disk.
///
/// The scan is driven against a **real** directory tree rather than a fake file system, because
/// every rule it has is a rule about what is on disk — a `.git` that is a directory versus one that
/// is a file, a name that merely contains a skipped one, a depth. A double would be asserting the
/// double.
@Suite("File system project folders")
struct FileSystemProjectFoldersTests {

    // MARK: - What is behind one project's folder

    @Test
    func `given a folder with worktrees when its contents are read then they are counted`() async throws {
        // given
        let scenario = try Scenario(
            worktrees: ["/repo", "/repo/.claude/worktrees/one", "/repo/.claude/worktrees/two"],
            isDirty: false
        )
        let repository = try scenario.makeDirectory(at: "repo")

        // when
        let contents = await scenario.sut.contents(ofFolderAt: repository.path(percentEncoded: false))

        // then
        #expect(contents == .worktrees(count: 3))
    }

    @Test
    func `given a folder that is not there when its contents are read then it says so`() async throws {
        // given — the state design §4 exists to repair. Today such a project still passes
        // `isVisible`, so the API serves it with zero worktrees, which on a phone is
        // indistinguishable from a project with nothing to read.
        let scenario = try Scenario(worktrees: ["/repo"], isDirty: false)

        // when
        let contents = await scenario.sut.contents(
            ofFolderAt: scenario.root.appending(path: "moved-away").path(percentEncoded: false)
        )

        // then
        #expect(contents == .folderNotFound)
    }

    @Test
    func `given a folder git will not read when its contents are read then it is not a repository`(
    ) async throws {
        // given — kept apart from a missing folder because only one of the two is what `Locate…`
        // fixes: a folder picker cannot turn a directory back into a checkout.
        let scenario = try Scenario(
            worktrees: [],
            isDirty: false,
            failure: .commandFailed(
                command: .worktrees,
                exitCode: 128,
                standardError: "fatal: not a git repository"
            )
        )
        let folder = try scenario.makeDirectory(at: "not-a-checkout")

        // when
        let contents = await scenario.sut.contents(ofFolderAt: folder.path(percentEncoded: false))

        // then
        #expect(contents == .notARepository)
    }

    @Test
    func `given a folder when its contents are read then only the worktree list is run`() async throws {
        // given
        let scenario = try Scenario(worktrees: ["/repo"], isDirty: false)
        let repository = try scenario.makeDirectory(at: "repo")

        // when
        _ = await scenario.sut.contents(ofFolderAt: repository.path(percentEncoded: false))

        // then — the cheap half of the pair, and cheap is the whole reason it is a separate call.
        // A reader opening this tab sees their list, not a spinner.
        #expect(await scenario.git.received == [.worktrees])
    }

    // MARK: - The expensive half

    @Test
    func `given every worktree is dirty when they are counted then all of them count`() async throws {
        // given
        let scenario = try Scenario(
            worktrees: ["/repo", "/repo/one", "/repo/two"],
            isDirty: true
        )
        let repository = try scenario.makeDirectory(at: "repo")

        // when
        let dirty = await scenario.sut.worktreesWithChanges(
            inFolderAt: repository.path(percentEncoded: false)
        )

        // then
        #expect(dirty == 3)
    }

    @Test
    func `given nothing uncommitted anywhere when worktrees are counted then none of them count`(
    ) async throws {
        // given
        let scenario = try Scenario(worktrees: ["/repo", "/repo/one"], isDirty: false)
        let repository = try scenario.makeDirectory(at: "repo")

        // when
        let dirty = await scenario.sut.worktreesWithChanges(
            inFolderAt: repository.path(percentEncoded: false)
        )

        // then
        #expect(dirty == 0)
    }

    @Test
    func `given git refuses for one worktree when they are counted then the rest still count`(
    ) async throws {
        // given — a worktree whose directory was deleted without git being told is ordinary, and it
        // must not take the figure for the whole project down with it.
        let scenario = try Scenario(
            worktrees: ["/repo"],
            isDirty: true,
            failure: .commandFailed(
                command: .worktreeStatus,
                exitCode: 128,
                standardError: "fatal: cannot chdir"
            )
        )
        let repository = try scenario.makeDirectory(at: "repo")

        // when
        let dirty = await scenario.sut.worktreesWithChanges(
            inFolderAt: repository.path(percentEncoded: false)
        )

        // then
        #expect(dirty == 0)
    }

    // MARK: - The scan

    @Test
    func `given repositories under a folder when it is scanned then each is offered once`(
    ) async throws {
        // given
        let scenario = try Scenario(worktrees: [], isDirty: false)
        try scenario.makeRepository(at: "granita")
        try scenario.makeRepository(at: "experiments/scratch")

        // when
        let found = await scenario.sut.repositories(under: scenario.root)

        // then — the relative path is what tells two repositories with one directory name apart,
        // which is ordinary in a folder somebody has worked in for a year.
        #expect(found.map(\.name) == ["granita", "scratch"])
        #expect(found.map(\.relativePath) == ["granita", "experiments/scratch"])
    }

    @Test
    func `given a repository inside a repository when scanning then only the outer one is offered`(
    ) async throws {
        // given — git will not descend into another checkout and neither does this. A repository's
        // own submodules and vendored copies are not projects a reader filed.
        let scenario = try Scenario(worktrees: [], isDirty: false)
        try scenario.makeRepository(at: "granita")
        try scenario.makeRepository(at: "granita/Packages/nested")

        // when
        let found = await scenario.sut.repositories(under: scenario.root)

        // then
        #expect(found.map(\.relativePath) == ["granita"])
    }

    @Test
    func `given the directories the specification skips when scanning then nothing inside is offered`(
    ) async throws {
        // given
        let scenario = try Scenario(worktrees: [], isDirty: false)
        try scenario.makeRepository(at: "node_modules/left-pad")
        try scenario.makeRepository(at: "vendor/swift-nio")
        try scenario.makeRepository(at: "Pods/Alamofire")
        try scenario.makeRepository(at: ".claude/worktrees/slice")
        try scenario.makeRepository(at: "keeper")

        // when
        let found = await scenario.sut.repositories(under: scenario.root)

        // then — `vendor/swift-nio` is the one the §4 frames draw, and the specification's list is
        // what wins. Settled with Davide on 23 August 2026; see `design-mac.md`.
        #expect(found.map(\.relativePath) == ["keeper"])
    }

    @Test
    func `given a linked worktree when scanning then it is not offered as a repository`() async throws {
        // given — a linked worktree's `.git` is a file rather than a directory, and adding one as a
        // project would enumerate the same worktrees the repository it belongs to already does.
        let scenario = try Scenario(worktrees: [], isDirty: false)
        let linked = try scenario.makeDirectory(at: "linked")
        try Data("gitdir: /elsewhere/.git/worktrees/linked".utf8)
            .write(to: linked.appending(path: ".git"))

        // when
        let found = await scenario.sut.repositories(under: scenario.root)

        // then
        #expect(found.isEmpty)
    }

    @Test
    func `given a repository deeper than a scan goes when scanning then it is not offered`() async throws {
        // given — a scan is a person pointing at where they keep their work, not a search of a disk.
        let scenario = try Scenario(worktrees: [], isDirty: false)
        try scenario.makeRepository(at: "a/b/c/d/too-deep")
        try scenario.makeRepository(at: "a/b/c/deep-enough")

        // when
        let found = await scenario.sut.repositories(under: scenario.root)

        // then
        #expect(found.map(\.relativePath) == ["a/b/c/deep-enough"])
    }

    @Test
    func `given a folder that is not there when it is scanned then nothing is found`() async throws {
        // given
        let scenario = try Scenario(worktrees: [], isDirty: false)

        // when
        let found = await scenario.sut.repositories(under: scenario.root.appending(path: "gone"))

        // then
        #expect(found.isEmpty)
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut: FileSystemProjectFolders
        let git: FakeGitClient
        let root: URL

        init(worktrees: [String], isDirty: Bool, failure: GitError? = nil) throws {
            root = URL(filePath: NSTemporaryDirectory())
                .appending(path: "granita-scan-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

            git = FakeGitClient(
                worktreeList: Self.porcelain(worktrees),
                status: isDirty ? Data("1 .M N... 100644 100644 100644 aaa bbb edited.swift\0".utf8) : Data(),
                failure: failure
            )
            sut = FileSystemProjectFolders(service: WorktreeService(git: git, limits: .standard))
        }

        func makeDirectory(at relativePath: String) throws -> URL {
            let url = root.appending(path: relativePath, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        func makeRepository(at relativePath: String) throws {
            _ = try makeDirectory(at: relativePath + "/.git")
        }

        /// `worktree list --porcelain -z`: one NUL-separated attribute per field, an empty field
        /// ending each record.
        private static func porcelain(_ paths: [String]) -> Data {
            var data = Data()
            for path in paths {
                data.append(contentsOf: Data("worktree \(path)".utf8))
                data.append(0)
                data.append(0)
            }
            return data
        }
    }
}

// MARK: -

/// git, answering only the two questions this seam asks it.
private actor FakeGitClient: GitClient {

    private let worktreeList: Data
    private let status: Data
    private let failure: GitError?
    private(set) var received: [GitCommand] = []

    init(worktreeList: Data, status: Data, failure: GitError?) {
        self.worktreeList = worktreeList
        self.status = status
        self.failure = failure
    }

    func run(_ command: GitCommand, in location: RepositoryLocation) throws(GitError) -> GitOutput {
        received.append(command)
        if let failure, failure.matches(command) { throw failure }
        switch command {
        case .worktrees: return GitOutput(standardOutput: worktreeList, isTruncated: false)
        case .worktreeStatus: return GitOutput(standardOutput: status, isTruncated: false)
        default: return GitOutput(standardOutput: Data(), isTruncated: false)
        }
    }
}

private extension GitError {

    /// Fails the one command the test aimed the failure at, so a scenario can refuse the worktree
    /// list without also refusing every status under it.
    func matches(_ command: GitCommand) -> Bool {
        switch self {
        case .commandFailed(let failed, _, _): failed == command
        case .terminatedBySignal(let failed, _, _): failed == command
        case .timedOut(let failed): failed == command
        case .gitUnavailable, .workingDirectoryUnreadable: true
        }
    }
}
