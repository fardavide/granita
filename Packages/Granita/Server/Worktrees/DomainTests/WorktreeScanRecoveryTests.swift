import Foundation
import Testing

import CoreApiDomain
import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain
import ServerWorktreesDomain

@Suite("Automatic worktree scan recovery")
struct WorktreeScanRecoveryTests {
    @Test(.timeLimit(.minutes(1)))
    func `given a registered checkout times out when Git becomes responsive then observation publishes its recovered row`() async throws {
        // given
        let location = RepositoryLocation(path: "/project")
        let worktree = WorktreeID(canonicalPath: location.path)
        let scenario = await Scenario(locations: [location], scanFailure: .timedOut(command: .worktreeStatus))
        var updates = await scenario.registry.observationUpdates().makeAsyncIterator()
        let initial = try #require(await updates.next())
        try #require(initial.issues.map(\.target) == [.worktree(worktree)])

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { await scenario.sut.run() }
            defer { group.cancelAll() }
            let failed = try #require(await updates.next())
            try #require(failed.issues.map(\.target) == [.worktree(worktree)])
            try #require(failed.worktrees.isEmpty)

            // when
            await scenario.git.allow(.worktreeStatus)
            group.addTask {
                while let delay = await scenario.timing.nextSleep() {
                    await scenario.timing.advance(by: delay)
                }
            }
            var recovered: WorktreeSnapshot?
            while let snapshot = await updates.next() {
                if snapshot.worktrees.contains(where: { $0.id == worktree }) {
                    recovered = snapshot
                    break
                }
            }

            // then
            let snapshot = try #require(recovered, "Expected automatic publication after the scan recovered")
            #expect(snapshot.worktrees.map(\.id) == [worktree])
            #expect(snapshot.issues.isEmpty)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a project now refuses enumeration when another checkout retries then only the recoverable checkout is rescanned`() async throws {
        // given
        let unavailable = RepositoryLocation(path: "/unavailable")
        let recovering = RepositoryLocation(path: "/recovering")
        let project = ProjectID(canonicalPath: unavailable.path)
        let worktree = WorktreeID(canonicalPath: recovering.path)
        let scenario = await Scenario(locations: [unavailable, recovering], scanFailure: .timedOut(command: .worktreeStatus))
        var updates = await scenario.registry.observationUpdates().makeAsyncIterator()
        let initial = try #require(await updates.next())
        try #require(initial.issues.count == 2)
        let delay = try #require(await scenario.timing.nextSleep())
        await scenario.git.refuseCommands(in: unavailable, with: .commandFailed(
            command: .worktrees, exitCode: 128, standardError: "fatal: not a git repository"
        ))
        await scenario.registry.reconcile()
        let failed = try #require(await updates.next())
        try #require(failed.issues.contains { $0.target == .project(project) && $0.reason == .gitFailure })
        let previousCalls = await scenario.git.locations.filter { $0 == unavailable }.count

        // when
        await scenario.git.allow(.worktreeStatus)
        await scenario.timing.advance(by: delay)
        let retried = await updates.next()
        await scenario.registry.stop()

        // then
        let snapshot = try #require(retried)
        #expect(snapshot.worktrees.map(\.id) == [worktree])
        #expect(await scenario.git.locations.filter { $0 == unavailable }.count == previousCalls)
    }

    private struct Scenario {
        let registry: WorktreeRegistry
        let git: FakeGitClient
        let timing: FakeWorktreeObservationTiming
        let sut: WorktreeObservation

        init(locations: [RepositoryLocation], scanFailure: GitError) async {
            git = FakeGitClient(outputs: [.headCommit: Data("abc123\n".utf8)], failures: [.worktreeStatus: scanFailure])
            for location in locations {
                let gitDirectory = Data("\(location.path)/.git\n".utf8)
                await git.answer(.worktrees, in: location, with: Data(
                    "worktree \(location.path)\0HEAD abc123\0branch refs/heads/main\0\0".utf8
                ))
                await git.answer(.repositoryRoot, in: location, with: Data("\(location.path)\n".utf8))
                await git.answer(.gitDirectory, in: location, with: gitDirectory)
                await git.answer(.commonGitDirectory, in: location, with: gitDirectory)
            }
            timing = FakeWorktreeObservationTiming()
            let store = FakeStore(projects: locations.map { location in
                StoredProject(id: ProjectID(canonicalPath: location.path), path: location.path, name: location.path, isVisible: true)
            })
            registry = WorktreeRegistry(
                store: store,
                service: WorktreeService(git: git, files: FakeWorktreeFileReading(), limits: .standard),
                directory: FakeWorktreeDirectoryReading(),
                suggestedAliases: { _ in [:] },
                now: { Date(timeIntervalSince1970: 1_800_000_100) },
                timing: timing
            )
            sut = WorktreeObservation(
                registry: registry,
                git: git,
                source: FakeWorktreeObservationSource(),
                store: store,
                onFailure: { Issue.record("Observation failed: \($0)") },
                timing: timing
            )
        }
    }
}
