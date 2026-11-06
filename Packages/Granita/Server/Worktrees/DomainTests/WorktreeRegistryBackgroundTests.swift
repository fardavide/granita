import Foundation
import Testing

import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain
import ServerWorktreesDomain

@Suite("Worktree registry background publication")
struct WorktreeRegistryBackgroundTests {
    @Test
    func `given a visible project has never scanned successfully when reconciliation fails then no partial inventory is published`() async throws {
        // given
        let scenario = await Scenario()
        await scenario.git.refuseCommands(in: scenario.unavailable, with: .commandFailed(
            command: .worktrees, exitCode: 128, standardError: "volume unavailable after restart"
        ))
        let stream = await scenario.sut.updates()

        // when
        await scenario.sut.reconcile()
        await scenario.sut.stop()
        var updates = stream.makeAsyncIterator()

        // then
        #expect(await updates.next() == nil)
    }

    @Test
    func `given a visible project root is missing after restart when its first reconciliation fails then no partial inventory is published`() async throws {
        // given
        let scenario = await Scenario(unavailableDirectoryExists: false)
        await scenario.git.refuseCommands(in: scenario.unavailable, with: .commandFailed(
            command: .worktrees, exitCode: 128, standardError: "volume unavailable after restart"
        ))
        let stream = await scenario.sut.updates()

        // when
        await scenario.sut.reconcile()
        await scenario.sut.stop()
        var updates = stream.makeAsyncIterator()

        // then
        #expect(await updates.next() == nil)
    }

    @Test
    func `given a cached project becomes unreadable when another project refreshes then its fresh content is published alongside the retained rows`() async throws {
        // given
        let scenario = await Scenario()
        var updates = await scenario.sut.updates().makeAsyncIterator()
        let original = try #require(await updates.next())
        let originalHealthy = try #require(original.worktrees.first { $0.id == scenario.healthyId })
        let originalUnavailable = try #require(original.worktrees.first { $0.id == scenario.unavailableId })
        await scenario.git.answer(.headCommit, in: scenario.healthy, with: Data("def456\n".utf8))
        await scenario.git.refuseCommands(in: scenario.unavailable, with: .commandFailed(
            command: .worktrees, exitCode: 128, standardError: "temporarily unavailable"
        ))

        // when
        await scenario.sut.reconcile()
        await scenario.sut.stop()

        // then
        let refreshed = try #require(await updates.next())
        #expect(refreshed.worktrees.first { $0.id == scenario.healthyId }?.revision != originalHealthy.revision)
        #expect(refreshed.worktrees.first { $0.id == scenario.unavailableId } == originalUnavailable)
        #expect(await updates.next() == nil)
    }

    private struct Scenario {
        let sut: WorktreeRegistry
        let git: FakeGitClient
        let healthy: RepositoryLocation
        let unavailable: RepositoryLocation
        let healthyId: WorktreeID
        let unavailableId: WorktreeID

        init(unavailableDirectoryExists: Bool = true) async {
            healthy = RepositoryLocation(path: "/healthy")
            unavailable = RepositoryLocation(path: "/unavailable")
            healthyId = WorktreeID(canonicalPath: healthy.path)
            unavailableId = WorktreeID(canonicalPath: unavailable.path)
            let git = FakeGitClient(outputs: [.headCommit: Data("abc123\n".utf8)], failures: [:])
            self.git = git
            for location in [healthy, unavailable] {
                await git.answer(.worktrees, in: location, with: Data(
                    "worktree \(location.path)\0HEAD abc123\0branch refs/heads/main\0\0".utf8
                ))
            }
            let projects = [healthy, unavailable].map {
                StoredProject(id: ProjectID(canonicalPath: $0.path), path: $0.path, name: $0.path, isVisible: true)
            }
            sut = WorktreeRegistry(
                store: FakeStore(projects: projects),
                service: WorktreeService(git: git, files: FakeWorktreeFileReading(), limits: .standard),
                directory: FakeWorktreeDirectoryReading(
                    missingLocations: unavailableDirectoryExists ? [] : [unavailable]
                ),
                suggestedAliases: { _ in [:] },
                now: { Date(timeIntervalSince1970: 1_800_000_100) }
            )
        }
    }
}
