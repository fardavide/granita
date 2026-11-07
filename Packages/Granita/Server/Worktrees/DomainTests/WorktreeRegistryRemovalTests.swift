import Foundation
import Testing

import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain
import ServerWorktreesDomain

@Suite("Worktree registry removal")
struct WorktreeRegistryRemovalTests {
    @Test(.timeLimit(.minutes(1)))
    func `given a scan captured a linked worktree when its removal succeeds then the scan keeps fresh surviving content without restoring the removed worktree`() async throws {
        // given
        let scenario = Scenario()
        let remaining = WorktreeID(canonicalPath: "/repo")
        let original = try #require(await scenario.sut.worktrees(inProject: nil).first { $0.id == remaining })
        var updates = await scenario.sut.updates().makeAsyncIterator()
        _ = await updates.next()
        await scenario.git.answer(.headCommit, with: Data("new-head\n".utf8))
        await scenario.git.pause(.worktreeStatus)
        let refreshing = Task { try await scenario.sut.worktrees(inProject: nil, refreshing: true) }
        await scenario.git.waitUntilPaused(.worktreeStatus)

        // when
        await scenario.sut.didRemove(WorktreeID(canonicalPath: "/worktrees/b"))
        await scenario.git.resume(.worktreeStatus)
        let refreshed = try await refreshing.value
        let rows = try await scenario.sut.worktrees(inProject: nil)
        await scenario.sut.stop()
        let published = await updates.next()

        // then
        #expect(refreshed.map(\.id) == [remaining])
        #expect(rows == refreshed)
        #expect(published?.worktrees.map(\.id) == [remaining])
        #expect(try #require(refreshed.first { $0.id == remaining }).revision != original.revision)
        #expect(await updates.next() == nil)
    }

    @Test
    func `given a cached linked worktree when its removal succeeds then the list and subscriber immediately omit it without git`() async throws {
        // given
        let scenario = Scenario()
        _ = try await scenario.sut.worktrees(inProject: nil)
        var updates = await scenario.sut.updates().makeAsyncIterator()
        _ = await updates.next()
        let commands = await scenario.git.received.count
        let remaining = WorktreeID(canonicalPath: "/repo")

        // when
        await scenario.sut.didRemove(WorktreeID(canonicalPath: "/worktrees/b"))
        let rows = try await scenario.sut.worktrees(inProject: nil)
        await scenario.sut.stop()
        let published = await updates.next()

        // then
        #expect(rows.map(\.id) == [remaining])
        #expect(published?.worktrees.map(\.id) == [remaining])
        #expect(await scenario.git.received.count == commands)
        #expect(await updates.next() == nil)
    }

    private struct Scenario {
        let sut: WorktreeRegistry
        let git: FakeGitClient

        init() {
            git = FakeGitClient(outputs: [
                .worktrees: Data((
                    "worktree /repo\0HEAD abc123\0branch refs/heads/main\0\0"
                    + "worktree /worktrees/b\0HEAD def456\0branch refs/heads/task\0\0"
                ).utf8),
                .headCommit: Data("abc123\n".utf8)
            ], failures: [:])
            sut = WorktreeRegistry(
                store: FakeStore(projects: [StoredProject(
                    id: ProjectID(canonicalPath: "/repo"), path: "/repo", name: "Reader", isVisible: true
                )]),
                service: WorktreeService(git: git, files: FakeWorktreeFileReading(), limits: .standard),
                directory: FakeWorktreeDirectoryReading(),
                suggestedAliases: { _ in [:] },
                now: { Date(timeIntervalSince1970: 1_800_000_100) }
            )
        }
    }
}
