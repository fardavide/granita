import Foundation
import Testing

import CoreApiDomain
import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain
import ServerWorktreesDomain

@Suite("Worktree registry refusal and fallback contracts")
struct WorktreeRegistryCoverageTests {
    @Test(arguments: [
        (WorktreeRegistryError.projectNotVisible, ApiErrorCode.projectNotVisible),
        (.directoryGone, .worktreeGone),
        (.notFound, .worktreeGone),
        (.git(.gitUnavailable(reason: "Git executable is unavailable")), .gitFailure),
        (.cancelled, .gitFailure)
    ])
    func `given a registry refusal when its public code is read then the boundary receives the matching code`(
        refusal: WorktreeRegistryError,
        expected: ApiErrorCode
    ) {
        // when - then
        #expect(refusal.code == expected)
    }

    @Test
    func `given a visible project cannot be scanned when summaries are read then the project remains listed without fabricated worktrees`() async {
        // given
        let scenario = Scenario(failures: [.worktreeStatus: .commandFailed(
            command: .worktreeStatus, exitCode: 128, standardError: "checkout is temporarily unavailable"
        )])

        // when
        let projects = await scenario.sut.projects()

        // then
        #expect(projects == [Project(
            id: ProjectID(canonicalPath: "/repo"), name: "Reader", isVisible: true,
            worktreeCount: 0, dirtyWorktreeCount: 0
        )])
    }

    @Test
    func `given a detached checkout has no stored or suggested name when listed then its directory names the row`() async throws {
        // given
        let scenario = Scenario(worktreeListing: "worktree /external/review-checkout\0HEAD abc123\0detached\0\0")

        // when
        let rows = try await scenario.sut.worktrees(inProject: nil)

        // then
        let row = try #require(rows.first)
        #expect(row.displayName == "review-checkout")
        #expect(row.branch == nil)
        #expect(row.isDetached)
    }

    @Test
    func `given a nonlocal branch reference when listed then its full spelling is preserved`() async throws {
        // given
        let scenario = Scenario(worktreeListing:
            "worktree /repo\0HEAD abc123\0branch refs/remotes/origin/review\0\0"
        )

        // when
        let rows = try await scenario.sut.worktrees(inProject: nil)

        // then
        #expect(rows.first?.branch == "refs/remotes/origin/review")
        #expect(rows.first?.displayName == "refs/remotes/origin/review")
    }

    @Test
    func `given a resolved checkout cannot read its changes when described then the Git refusal reaches its caller`() async throws {
        // given
        let failure = GitError.commandFailed(
            command: .worktreeStatus, exitCode: 128, standardError: "fatal: index could not be read"
        )
        let scenario = Scenario(failures: [.worktreeStatus: failure])
        let resolved = try await scenario.sut.resolve(WorktreeID(canonicalPath: "/repo"))

        // when - then
        await #expect(throws: WorktreeRegistryError.git(failure)) {
            try await scenario.sut.worktree(resolved)
        }
    }

    @Test
    func `given one enabled project cannot enumerate when resolving another project then the healthy checkout remains resolvable`() async throws {
        // given
        let scenario = Scenario()
        await scenario.git.refuseCommands(in: RepositoryLocation(path: "/repo"), with: .commandFailed(
            command: .worktrees, exitCode: 128, standardError: "volume is not mounted"
        ))
        let healthy = RepositoryLocation(path: "/healthy")
        await scenario.store.add(project: StoredProject(
            id: ProjectID(canonicalPath: healthy.path), path: healthy.path,
            name: "Healthy project", isVisible: true
        ))
        await scenario.git.answer(.worktrees, in: healthy, with: Data(
            "worktree /healthy\0HEAD def456\0branch refs/heads/ready\0\0".utf8
        ))

        // when
        let resolved = try await scenario.sut.resolve(WorktreeID(canonicalPath: healthy.path))

        // then
        #expect(resolved.location == healthy)
        #expect(resolved.project.name == "Healthy project")
    }

    @Test
    func `given a visible project has never scanned when observation roots are read then its stored root is still available`() async {
        // given
        let scenario = Scenario()

        // when
        let locations = await scenario.sut.observationLocations()

        // then
        #expect(locations == [RepositoryLocation(path: "/repo")])
        #expect(await scenario.git.received.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given an overlay is rendering when a newly enabled project cannot scan then no partial inventory is published`() async throws {
        // given
        let scenario = Scenario(pausingAliasesAt: 2)
        var updates = await scenario.sut.updates().makeAsyncIterator()
        _ = try #require(await updates.next())
        let publishing = Task { await scenario.sut.storeDidChange() }
        await scenario.aliases.waitUntilPaused()
        let added = RepositoryLocation(path: "/unmounted-project")
        await scenario.git.refuseCommands(in: added, with: .workingDirectoryUnreadable(
            location: added, reason: "volume is not mounted"
        ))

        // when
        await scenario.store.add(project: StoredProject(
            id: ProjectID(canonicalPath: added.path), path: added.path, name: "Unavailable project", isVisible: true
        ))
        await scenario.aliases.resume()
        await publishing.value
        await scenario.sut.stop()

        // then
        #expect(await updates.next() == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given an initial snapshot waits for stored state when stopped then its late read cannot start a scan`() async {
        // given
        let scenario = Scenario()
        await scenario.store.pauseNextStateRead()
        let reading = Task { try await scenario.sut.snapshot(inProject: nil, refreshing: false) }
        await scenario.store.waitUntilStateReadPaused()

        // when
        await scenario.sut.stop()
        await scenario.store.resumeStateRead()

        // then
        await #expect(throws: WorktreeRegistryError.cancelled) { try await reading.value }
        #expect(await scenario.git.received.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given project summaries wait for stored state when stopped then only document metadata is returned without scanning`() async {
        // given
        let scenario = Scenario()
        await scenario.store.pauseNextStateRead()
        let reading = Task { await scenario.sut.projects() }
        await scenario.store.waitUntilStateReadPaused()

        // when
        await scenario.sut.stop()
        await scenario.store.resumeStateRead()
        let projects = await reading.value

        // then
        #expect(projects == [Project(
            id: ProjectID(canonicalPath: "/repo"), name: "Reader", isVisible: true,
            worktreeCount: 0, dirtyWorktreeCount: 0
        )])
        #expect(await scenario.git.received.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a warm project is disabled during a scan when that scan finishes then its late content cannot replace the cache`() async throws {
        // given
        let scenario = Scenario()
        let original = try #require(try await scenario.sut.worktrees(inProject: nil).first)
        await scenario.git.answer(.headCommit, with: Data("def456\n".utf8))
        await scenario.git.pause(.worktreeStatus)
        let refreshing = Task { try await scenario.sut.worktrees(inProject: nil, refreshing: true) }
        await scenario.git.waitUntilPaused(.worktreeStatus)

        // when
        await scenario.store.setProjectVisible(false, id: original.projectId)
        await scenario.git.resume(.worktreeStatus)
        let hidden = try await refreshing.value
        await scenario.store.setProjectVisible(true, id: original.projectId)
        let retained = try await scenario.sut.worktrees(inProject: nil)
        let fresh = try await scenario.sut.worktrees(inProject: nil, refreshing: true)

        // then
        #expect(hidden.isEmpty)
        #expect(retained.first?.revision == original.revision)
        #expect(fresh.first?.revision != original.revision)
    }

    private struct Scenario {
        let sut: WorktreeRegistry
        let git: FakeGitClient
        let store: FakeStore
        let aliases: FakeSuggestedAliases

        init(
            worktreeListing: String = "worktree /repo\0HEAD abc123\0branch refs/heads/main\0\0",
            failures: [GitCommand: GitError] = [:],
            pausingAliasesAt: Int = .max
        ) {
            git = FakeGitClient(outputs: [
                .worktrees: Data(worktreeListing.utf8),
                .headCommit: Data("abc123\n".utf8)
            ], failures: failures)
            store = FakeStore(projects: [StoredProject(
                id: ProjectID(canonicalPath: "/repo"), path: "/repo", name: "Reader", isVisible: true
            )])
            let aliases = FakeSuggestedAliases(pausingInvocation: pausingAliasesAt)
            self.aliases = aliases
            sut = WorktreeRegistry(
                store: store,
                service: WorktreeService(git: git, files: FakeWorktreeFileReading(), limits: .standard),
                directory: FakeWorktreeDirectoryReading(),
                suggestedAliases: { await aliases.aliases(for: $0) },
                now: { Date(timeIntervalSince1970: 1_800_000_100) }
            )
        }
    }
}
