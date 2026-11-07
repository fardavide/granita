import Foundation
import Testing

import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain
import ServerWorktreesDomain

@Suite("Worktree registry rendering")
struct WorktreeRegistryRenderingTests {
    @Test(.timeLimit(.minutes(1)), arguments: [true, false])
    func `given subscription rendering is paused when another project is enabled then only a complete inventory is published`(isReadable: Bool) async throws {
        // given
        let scenario = Scenario()
        _ = try await scenario.sut.worktrees(inProject: nil)
        let subscribing = Task { await scenario.sut.updates() }
        await scenario.aliases.waitUntilPaused()
        let added = RepositoryLocation(path: "/new-project")
        if isReadable {
            await scenario.git.answer(.worktrees, in: added, with: Data(
                "worktree \(added.path)\0HEAD def456\0branch refs/heads/new-project\0\0".utf8
            ))
        } else {
            await scenario.git.refuseCommands(in: added, with: .commandFailed(
                command: .worktrees, exitCode: 128, standardError: "project volume unavailable"
            ))
        }

        // when
        await scenario.store.add(project: StoredProject(
            id: ProjectID(canonicalPath: added.path), path: added.path,
            name: "New project", isVisible: true
        ))
        await scenario.aliases.resume()
        let subscription = await subscribing.value
        await scenario.sut.stop()
        var received = subscription.makeAsyncIterator()

        // then
        let expected: [WorktreeID]? = isReadable ? [
            WorktreeID(canonicalPath: "/repo"), WorktreeID(canonicalPath: added.path)
        ] : nil
        #expect(await received.next()?.worktrees.map(\.id) == expected)
    }

    @Test
    func `given an initial subscription cannot scan git when git recovers then reconciliation reaches that subscriber`() async {
        // given
        let location = RepositoryLocation(path: "/repo")
        let scenario = Scenario(pausingAliasInvocation: .max, failuresByLocation: [
            location: .commandFailed(command: .worktrees, exitCode: 128, standardError: "repository unavailable")
        ])
        let subscription = await scenario.sut.updates()

        // when
        await scenario.git.allowCommands(in: location)
        await scenario.sut.reconcile()
        await scenario.sut.stop()
        var received = subscription.makeAsyncIterator()

        // then
        #expect(await received.next()?.worktrees.map(\.id) == [WorktreeID(canonicalPath: location.path)])
        #expect(await received.next() == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given initial subscription rendering is paused when the registry stops then it cannot seed or register a late stream`() async throws {
        // given
        let scenario = Scenario()
        _ = try await scenario.sut.worktrees(inProject: nil)
        let subscribing = Task { await scenario.sut.updates() }
        await scenario.aliases.waitUntilPaused()

        // when
        await scenario.sut.stop()
        await scenario.aliases.resume()
        let subscription = await subscribing.value
        var received = subscription.makeAsyncIterator()
        let first = await received.next()
        await scenario.sut.stop()

        // then
        #expect(first == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given initial subscription rendering is paused when a refresh publishes newer content then the subscriber starts with that newest snapshot`() async throws {
        // given
        let scenario = Scenario()
        var published = await scenario.sut.updates().makeAsyncIterator()
        let original = try #require(await published.next())
        let worktree = try #require(original.worktrees.first)
        let subscribing = Task { await scenario.sut.updates() }
        await scenario.aliases.waitUntilPaused()

        // when
        await scenario.git.answer(.headCommit, with: Data("def456\n".utf8))
        await scenario.sut.refresh(in: [worktree.id])
        let newestPublished = try #require(await published.next())
        await scenario.aliases.resume()
        let subscription = await subscribing.value
        await scenario.sut.stop()
        var received = subscription.makeAsyncIterator()

        // then
        #expect(newestPublished.worktrees.first?.revision != worktree.revision)
        #expect(await received.next() == newestPublished)
        #expect(await received.next() == nil)
    }

    private struct Scenario {
        let sut: WorktreeRegistry
        let git: FakeGitClient
        let aliases: FakeSuggestedAliases
        let store: FakeStore

        init(
            pausingAliasInvocation: Int = 2,
            failuresByLocation: [RepositoryLocation: GitError] = [:]
        ) {
            git = FakeGitClient(outputs: [
                .worktrees: Data("worktree /repo\0HEAD abc123\0branch refs/heads/main\0\0".utf8),
                .headCommit: Data("abc123\n".utf8)
            ], failures: [:], failuresByLocation: failuresByLocation)
            let aliases = FakeSuggestedAliases(pausingInvocation: pausingAliasInvocation)
            self.aliases = aliases
            store = FakeStore(projects: [StoredProject(
                id: ProjectID(canonicalPath: "/repo"), path: "/repo", name: "Reader", isVisible: true
            )])
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
