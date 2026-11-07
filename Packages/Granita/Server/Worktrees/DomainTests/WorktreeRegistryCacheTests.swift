import Foundation
import Testing

import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain
@testable import ServerWorktreesDomain

@Suite("Worktree registry cache", .serialized)
struct WorktreeRegistryCacheTests {

    @Test
    func `given a warm list when listed again then no git commands run`() async throws {
        // given
        let scenario = Scenario()
        let first = try await scenario.sut.worktrees(inProject: nil)
        let initialCommands = await scenario.git.received.count

        // when
        let second = try await scenario.sut.worktrees(inProject: nil)

        // then
        #expect(first.count == 1)
        #expect(second == first)
        #expect(await scenario.git.received.count == initialCommands)
    }

    @Test
    func `given a warm list when explicitly refreshed then git scans it again`() async throws {
        // given
        let scenario = Scenario()
        _ = try await scenario.sut.worktrees(inProject: nil)
        let initialCommands = await scenario.git.received.count

        // when
        _ = try await scenario.sut.worktrees(inProject: nil, refreshing: true)

        // then
        #expect(await scenario.git.received.count == initialCommands * 2)
    }

    @Test
    func `given git refuses an initial scan when listing then the failure reaches the reader`() async {
        // given
        let failure = GitError.commandFailed(
            command: .worktreeStatus,
            exitCode: 128,
            standardError: "fatal: repository volume is unavailable"
        )
        let scenario = Scenario(failure: failure)

        // when - then
        await #expect(throws: WorktreeRegistryError.git(failure)) {
            try await scenario.sut.worktrees(inProject: nil)
        }
    }

    @Test
    func `given a warm list when observing then its current snapshot arrives without scanning`() async throws {
        // given
        let scenario = Scenario()
        let rows = try await scenario.sut.worktrees(inProject: nil)
        let initialCommands = await scenario.git.received.count

        // when
        var updates = await scenario.sut.updates().makeAsyncIterator()
        let first = await updates.next()

        // then
        #expect(first?.worktrees == rows)
        #expect(first?.scannedAt == Date(timeIntervalSince1970: 1_800_000_100))
        #expect(await scenario.git.received.count == initialCommands)
    }

    @Test
    func `given two warm worktrees when one changes then only that worktree is rescanned`() async throws {
        // given
        let changed = RepositoryLocation(path: "/worktrees/agent")
        let scenario = Scenario(worktrees: [RepositoryLocation(path: "/repo"), changed])
        _ = try await scenario.sut.worktrees(inProject: nil)
        let initialCommands = await scenario.git.received.count

        // when
        await scenario.sut.refresh(in: [WorktreeID(canonicalPath: changed.path)])

        // then
        let commands = await scenario.git.received
        let locations = await scenario.git.locations
        let statuses = zip(commands, locations).dropFirst(initialCommands)
            .filter { $0.0 == .worktreeStatus }
        #expect(statuses.map(\.1) == [changed])
    }

    @Test
    func `given a new checkout when reconciling then the prepared inventory includes it`() async throws {
        // given
        let scenario = Scenario()
        _ = try await scenario.sut.worktrees(inProject: nil)
        await scenario.git.answer(.worktrees, with: Data(
            ("worktree /repo\0HEAD abc123\0branch refs/heads/main\0\0"
                + "worktree /worktrees/new-task\0HEAD def456\0branch refs/heads/new-task\0\0").utf8
        ))

        // when
        await scenario.sut.reconcile()

        // then
        let rows = try await scenario.sut.worktrees(inProject: nil)
        #expect(rows.map(\.id) == [
            WorktreeID(canonicalPath: "/repo"),
            WorktreeID(canonicalPath: "/worktrees/new-task")
        ])
    }

    @Test
    func `given observed inventory when its stored alias changes then the updated snapshot arrives without git`() async throws {
        // given
        let scenario = Scenario()
        var updates = await scenario.sut.updates().makeAsyncIterator()
        _ = await updates.next()
        let roots = await scenario.sut.observationLocations()
        let root = try #require(roots.first)
        let initialCommands = await scenario.git.received.count
        await scenario.store.setAlias("Ready to review", for: WorktreeID(canonicalPath: root.path))

        // when
        await scenario.sut.storeDidChange()
        let updated = await updates.next()

        // then
        #expect(updated?.worktrees.first?.displayName == "Ready to review")
        #expect(await scenario.git.received.count == initialCommands)
    }

    @Test
    func `given cached changes when a current file is marked viewed then the next list overlays its mark without git`() async throws {
        // given
        let scenario = Scenario()
        await scenario.git.answer(
            .trackedChanges(against: .head),
            with: Data(":100644 100644 aaa 0000000 M\0review.swift\0".utf8)
        )
        await scenario.git.answer(.trackedStats(against: .head), with: Data("1\t0\treview.swift\0".utf8))
        let changes = try await WorktreeService(
            git: scenario.git,
            files: FakeWorktreeFileReading(),
            limits: .standard
        ).changeSet(in: RepositoryLocation(path: "/repo"), viewed: [:])
        let file = try #require(changes.files.first)
        _ = try await scenario.sut.worktrees(inProject: nil)
        let initialCommands = await scenario.git.received.count
        await scenario.store.setViewed(
            true,
            file: file.id,
            in: WorktreeID(canonicalPath: "/repo"),
            contentHash: file.contentHash,
            at: Date(timeIntervalSince1970: 1_800_000_110)
        )

        // when
        let rows = try await scenario.sut.worktrees(inProject: nil)

        // then
        #expect(rows.first?.viewedFileCount == 1)
        #expect(await scenario.git.received.count == initialCommands)
    }

    @Test
    func `given a subscriber when its worktree refreshes then the changed snapshot arrives before shutdown`() async throws {
        // given
        let scenario = Scenario()
        var updates = await scenario.sut.updates().makeAsyncIterator()
        let initial = try #require(await updates.next())
        let worktree = try #require(initial.worktrees.first)
        await scenario.git.answer(
            .trackedChanges(against: .head),
            with: Data(":100644 100644 aaa 0000000 M\0review.swift\0".utf8)
        )
        await scenario.git.answer(.trackedStats(against: .head), with: Data("1\t0\treview.swift\0".utf8))

        // when
        await scenario.sut.refresh(in: [worktree.id])
        await scenario.sut.stop()

        // then
        let updated = try #require(await updates.next())
        #expect(updated.worktrees.first?.stats.filesChanged == 1)
        #expect(updated.worktrees.first?.revision != worktree.revision)
    }

    @Test
    func `given a successful snapshot when an explicit refresh fails then ordinary reads retain that snapshot without git`() async throws {
        // given
        let scenario = Scenario()
        let first = try await scenario.sut.worktrees(inProject: nil)
        let failure = GitError.commandFailed(
            command: .worktreeStatus,
            exitCode: 128,
            standardError: "fatal: checkout is temporarily unreadable"
        )
        await scenario.git.refuse(.worktreeStatus, with: failure)

        // when
        await #expect(throws: WorktreeRegistryError.git(failure)) {
            try await scenario.sut.worktrees(inProject: nil, refreshing: true)
        }
        let afterFailure = await scenario.git.received.count
        let retained = try await scenario.sut.worktrees(inProject: nil)

        // then
        #expect(retained == first)
        #expect(await scenario.git.received.count == afterFailure)
    }

    @Test
    func `given a successful snapshot when background refresh fails then ordinary reads retain that snapshot without git`() async throws {
        // given
        let scenario = Scenario()
        let first = try await scenario.sut.worktrees(inProject: nil)
        await scenario.git.refuse(.worktreeStatus, with: .commandFailed(
            command: .worktreeStatus,
            exitCode: 128,
            standardError: "fatal: checkout is temporarily unreadable"
        ))

        // when
        await scenario.sut.refresh(in: [WorktreeID(canonicalPath: "/repo")])
        let afterFailure = await scenario.git.received.count
        let retained = try await scenario.sut.worktrees(inProject: nil)

        // then
        #expect(retained == first)
        #expect(await scenario.git.received.count == afterFailure)
    }

    @Test
    func `given simultaneous cold readers when listing then they share one scan`() async throws {
        // given
        let scenario = Scenario()

        // when
        async let first = scenario.sut.worktrees(inProject: nil)
        async let second = scenario.sut.worktrees(inProject: nil)
        let rows = try await (first, second)

        // then
        #expect(rows.0 == rows.1)
        #expect(await scenario.git.received.count(where: { $0 == .worktrees }) == 1)
        #expect(await scenario.git.received.count(where: { $0 == .worktreeStatus }) == 1)
    }

    @Test
    func `given overlapping refreshes when scanning then queued invalidations coalesce into one followup`() async throws {
        // given
        let scenario = Scenario()
        _ = try await scenario.sut.worktrees(inProject: nil)
        let initial = await scenario.git.received.count(where: { $0 == .worktreeStatus })
        let worktree = WorktreeID(canonicalPath: "/repo")

        // when
        async let first = scenario.sut.refresh(in: [worktree])
        async let second = scenario.sut.refresh(in: [worktree])
        async let third = scenario.sut.refresh(in: [worktree])
        _ = await (first, second, third)

        // then
        let rescans = await scenario.git.received.count(where: { $0 == .worktreeStatus }) - initial
        #expect(rescans <= 2)
    }

    @Test
    func `given a paused forced scan when stopped then it fails without restarting git work`() async throws {
        // given
        let scenario = Scenario()
        _ = try await scenario.sut.worktrees(inProject: nil)
        await scenario.git.pause(.worktreeStatus)
        let refreshing = Task { try await scenario.sut.worktrees(inProject: nil, refreshing: true) }
        await scenario.git.waitUntilPaused(.worktreeStatus)
        let beforeStop = await scenario.git.received.count(where: { $0 == .worktrees })

        // when
        await scenario.sut.stop()

        // then
        await #expect(throws: WorktreeRegistryError.cancelled) { try await refreshing.value }
        let afterStop = await scenario.git.received.count(where: { $0 == .worktrees })
        #expect(afterStop == beforeStop)
    }

    @Test
    func `given a subscriber when inventory is reconciled then the new checkout is published`() async throws {
        // given
        let scenario = Scenario()
        var updates = await scenario.sut.updates().makeAsyncIterator()
        _ = await updates.next()
        await scenario.git.answer(.worktrees, with: Data(
            ("worktree /repo\0HEAD abc123\0branch refs/heads/main\0\0"
                + "worktree /worktrees/new-task\0HEAD def456\0branch refs/heads/new-task\0\0").utf8
        ))

        // when
        await scenario.sut.reconcile()
        await scenario.sut.stop()

        // then
        let updated = try #require(await updates.next())
        #expect(updated.worktrees.map(\.id) == [
            WorktreeID(canonicalPath: "/repo"),
            WorktreeID(canonicalPath: "/worktrees/new-task")
        ])
    }

    @Test
    func `given a prepared list when a snapshot is read later then its scan age is retained without git`() async throws {
        // given
        let scenario = Scenario()
        let scannedAt = scenario.time.now
        _ = try await scenario.sut.worktrees(inProject: nil)
        let initialCommands = await scenario.git.received.count
        scenario.time.advance(by: 3_600)

        // when
        let snapshot = try await scenario.sut.snapshot(inProject: nil, refreshing: false)

        // then
        #expect(snapshot.scannedAt == scannedAt)
        #expect(snapshot.worktrees.count == 1)
        #expect(await scenario.git.received.count == initialCommands)
    }

    @Test
    func `given a warm worktree list when project summaries are read then no git commands run`() async throws {
        // given
        let scenario = Scenario()
        _ = try await scenario.sut.worktrees(inProject: nil)
        let initialCommands = await scenario.git.received.count

        // when
        let projects = await scenario.sut.projects()

        // then
        #expect(projects.first?.worktreeCount == 1)
        #expect(await scenario.git.received.count == initialCommands)
    }

    @Test
    func `given a second project stored under a legacy alias when listing then its first checkout is primary`() async throws {
        // given
        let scenario = Scenario()
        let storedRoot = RepositoryLocation(path: "/legacy/second-project")
        let canonicalRoot = RepositoryLocation(path: "/canonical/second-project")
        let project = StoredProject(
            id: ProjectID(canonicalPath: storedRoot.path),
            path: storedRoot.path,
            name: "Second project",
            isVisible: true
        )
        await scenario.store.add(project: project)
        await scenario.git.answer(.worktrees, in: storedRoot, with: Data(
            "worktree \(canonicalRoot.path)\0HEAD def456\0branch refs/heads/secondary-main\0\0".utf8
        ))
        await scenario.git.answer(.headCommit, in: canonicalRoot, with: Data("def456\n".utf8))

        // when
        let rows = try await scenario.sut.worktrees(inProject: nil)

        // then
        let primary = try #require(rows.first { $0.projectId == project.id })
        #expect(primary.isPrimary)
    }

    private struct Scenario {

        let sut: WorktreeRegistry
        let git: FakeGitClient
        let store: FakeStore
        let time: FakeWorktreeTime

        init(
            failure: GitError? = nil,
            worktrees: [RepositoryLocation] = [RepositoryLocation(path: "/repo")]
        ) {
            let time = FakeWorktreeTime(at: Date(timeIntervalSince1970: 1_800_000_100))
            self.time = time
            store = FakeStore(projects: [StoredProject(
                id: ProjectID(canonicalPath: "/repo"),
                path: "/repo",
                name: "Reader",
                isVisible: true
            )])
            git = FakeGitClient(
                outputs: [
                    .worktrees: Data(worktrees.map {
                        "worktree \($0.path)\0HEAD abc123\0branch refs/heads/main\0\0"
                    }.joined().utf8),
                    .headCommit: Data("abc123\n".utf8)
                ],
                failures: failure.map { [.worktreeStatus: $0] } ?? [:]
            )
            sut = WorktreeRegistry(
                store: store,
                service: WorktreeService(git: git, files: FakeWorktreeFileReading(), limits: .standard),
                directory: FakeWorktreeDirectoryReading(),
                suggestedAliases: { _ in [:] },
                now: { time.now }
            )
        }
    }
}
