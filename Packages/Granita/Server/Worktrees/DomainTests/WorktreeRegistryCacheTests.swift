import Foundation
import Testing

import CoreApiDomain
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
    func `given a stale linked worktree when reading the first snapshot then healthy siblings remain visible`() async throws {
        // given
        let scenario = Scenario()
        let stale = RepositoryLocation(path: "/worktrees/removed-task")
        let healthy = RepositoryLocation(path: "/worktrees/current-task")
        await scenario.git.answer(.worktrees, with: Data(
            ("worktree /repo\0HEAD abc123\0branch refs/heads/main\0\0"
                + "worktree \(stale.path)\0HEAD def456\0branch refs/heads/removed-task\0"
                + "prunable gitdir file points to non-existent location\0\0"
                + "worktree \(healthy.path)\0HEAD 123abc\0branch refs/heads/current-task\0\0").utf8
        ))
        await scenario.git.refuseCommands(in: stale, with: .commandFailed(
            command: .headCommit,
            exitCode: 128,
            standardError: "fatal: not a git repository (or any of the parent directories): .git"
        ))

        // when
        let snapshot = try await scenario.sut.snapshot(inProject: nil, refreshing: false, allowPartial: true)

        // then
        #expect(snapshot.worktrees.map(\.id) == [
            WorktreeID(canonicalPath: "/repo"),
            WorktreeID(canonicalPath: healthy.path)
        ])
        #expect(snapshot.issues == [WorktreeScanIssue(
            target: .worktree(WorktreeID(canonicalPath: stale.path)),
            projectID: ProjectID(canonicalPath: "/repo"),
            name: "removed-task",
            projectName: "Reader",
            reason: .staleRegistration,
            lastRead: .never
        )])
    }

    @Test
    func `given a temporarily unavailable worktree when retried then only that checkout is rescanned`() async throws {
        // given
        let unavailable = RepositoryLocation(path: "/worktrees/temporarily-unavailable")
        let unavailableID = WorktreeID(canonicalPath: unavailable.path)
        let scenario = Scenario(worktrees: [RepositoryLocation(path: "/repo"), unavailable])
        let read = try await scenario.sut.snapshot(inProject: nil, refreshing: false, allowPartial: true)
        scenario.time.advance(by: 1_200)
        await scenario.git.refuseCommands(in: unavailable, with: .commandFailed(
            command: .headCommit, exitCode: 128, standardError: "checkout temporarily unreadable"
        ))
        await scenario.sut.refresh(in: [unavailableID])
        let stale = try await scenario.sut.snapshot(inProject: nil, refreshing: false, allowPartial: true)
        #expect(stale.issues.first?.lastRead == .at(read.scannedAt))
        let beforeRetry = await scenario.git.received.count
        await scenario.git.allowCommands(in: unavailable)

        // when
        let retried = try await scenario.sut.retry(.worktree(unavailableID))

        // then
        #expect(retried.issues.isEmpty)
        #expect(retried.worktrees.map(\.id) == read.worktrees.map(\.id))
        let commands = await scenario.git.received
        let locations = await scenario.git.locations
        let scanned = zip(commands, locations).dropFirst(beforeRetry).filter { $0.0 == .worktreeStatus }
        #expect(scanned.map(\.1) == [unavailable])
    }

    @Test(arguments: [false, true])
    func `given a project root cannot be read when the list is scanned then its issue reports the last successful inventory`(
        previouslyScanned: Bool
    ) async throws {
        // given
        let scenario = Scenario()
        let root = RepositoryLocation(path: "/work/Print Tools")
        let project = StoredProject(id: ProjectID(canonicalPath: root.path), path: root.path, name: "Print Tools", isVisible: true)
        await scenario.store.add(project: project)
        await scenario.git.answer(.worktrees, in: root, with: Data(
            "worktree \(root.path)\0HEAD abc123\0branch refs/heads/main\0\0".utf8
        ))
        if previouslyScanned {
            _ = try await scenario.sut.snapshot(inProject: nil, refreshing: false, allowPartial: true)
        }
        scenario.time.advance(by: 2_400)
        await scenario.git.refuseCommands(in: root, with: .commandFailed(
            command: .worktrees, exitCode: 128, standardError: "The project volume is offline"
        ))

        // when
        let snapshot = try await scenario.sut.snapshot(inProject: nil, refreshing: true, allowPartial: true)

        // then
        #expect(Set(snapshot.worktrees.map(\.id)) == Set([
            WorktreeID(canonicalPath: "/repo")
        ] + (previouslyScanned ? [WorktreeID(canonicalPath: root.path)] : [])))
        #expect(snapshot.issues == [WorktreeScanIssue(
            target: .project(project.id),
            projectID: project.id,
            name: "Print Tools",
            projectName: "Print Tools",
            reason: .gitFailure,
            lastRead: previouslyScanned ? .at(Date(timeIntervalSince1970: 1_800_000_100)) : .never
        )])
    }

    @Test
    func `given a failed project inventory when that project returns then retry refreshes only its inventory`() async throws {
        // given
        let scenario = Scenario()
        let root = RepositoryLocation(path: "/work/Print Tools")
        let project = StoredProject(id: ProjectID(canonicalPath: root.path), path: root.path, name: "Print Tools", isVisible: true)
        await scenario.store.add(project: project)
        await scenario.git.refuseCommands(in: root, with: .commandFailed(
            command: .worktrees, exitCode: 128, standardError: "The project volume is offline"
        ))
        let failed = try await scenario.sut.snapshot(inProject: nil, refreshing: false, allowPartial: true)
        try #require(failed.issues.map(\.target) == [.project(project.id)])
        let commandsBeforeRetry = await scenario.git.received.count
        await scenario.git.allowCommands(in: root)
        await scenario.git.answer(.worktrees, in: root, with: Data("worktree \(root.path)\0HEAD abc123\0detached\0\0".utf8))

        // when
        let recovered = try await scenario.sut.retry(.project(project.id))

        // then
        #expect(recovered.issues.isEmpty)
        #expect(Set(recovered.worktrees.map(\.id)) == [WorktreeID(canonicalPath: "/repo"), WorktreeID(canonicalPath: root.path)])
        #expect(Set(await scenario.git.locations.dropFirst(commandsBeforeRetry)) == [root])
    }

    @Test(arguments: [true, false])
    func `given a detached stale registration when subscribers connect then only a partial reader gets an unavailable row`(
        allowPartial: Bool
    ) async throws {
        // given
        let scenario = Scenario()
        let stale = WorktreeID(canonicalPath: "/worktrees/expired-preview")
        await scenario.git.answer(.worktrees, with: Data(
            ("worktree /repo\0HEAD abc123\0branch refs/heads/main\0\0"
                + "worktree /worktrees/expired-preview\0HEAD def456\0detached\0"
                + "prunable gitdir file points to non-existent location\0\0").utf8
        ))

        // when
        var events = await scenario.sut.updates(allowPartial: allowPartial).makeAsyncIterator()
        await scenario.sut.storeDidChange()
        await scenario.sut.stop()
        let snapshot = await events.next()

        // then
        if allowPartial {
            let snapshot = try #require(snapshot)
            #expect(snapshot.worktrees.map(\.id) == [WorktreeID(canonicalPath: "/repo")])
            #expect(snapshot.issues.first?.target == .worktree(stale))
            #expect(snapshot.issues.first?.name == "expired-preview")
        } else {
            #expect(snapshot == nil)
        }
    }

    @Test
    func `given an older subscriber already has a full inventory when a project goes offline then its cached rows still receive aliases`() async throws {
        // given
        let scenario = Scenario()
        let worktree = WorktreeID(canonicalPath: "/repo")
        var events = await scenario.sut.updates().makeAsyncIterator()
        let first = try #require(await events.next())
        await scenario.git.refuseCommands(in: RepositoryLocation(path: "/repo"), with: .commandFailed(
            command: .worktrees, exitCode: 128, standardError: "The project volume is offline"
        ))
        await scenario.store.setAlias("Print review", for: worktree)

        // when
        await scenario.sut.reconcile()
        await scenario.sut.stop()

        // then
        let update = try #require(await events.next())
        #expect(update.worktrees.map(\.id) == [worktree])
        #expect(update.worktrees.first?.alias == "Print review")
        #expect(update.scannedAt == first.scannedAt)
        #expect(update.issues.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func `given a stale registration lookup is in progress when observation ends or the project is hidden then it cannot be repaired`(
        hidingProject: Bool
    ) async {
        // given
        let scenario = Scenario()
        let stale = WorktreeID(canonicalPath: "/worktrees/retired-print-preview")
        await scenario.git.answer(.worktrees, with: Data(
            ("worktree /repo\0HEAD abc123\0branch refs/heads/main\0\0"
                + "worktree /worktrees/retired-print-preview\0HEAD def456\0detached\0"
                + "prunable gitdir file points to non-existent location\0\0").utf8
        ))
        await scenario.git.pause(.worktrees)
        let lookup = Task { try await scenario.sut.prunableProject(for: stale) }
        await scenario.git.waitUntilPaused(.worktrees)

        // when
        if hidingProject {
            await scenario.store.setProjectVisible(false, id: ProjectID(canonicalPath: "/repo"))
        } else {
            await scenario.sut.stop()
        }
        await scenario.git.resume(.worktrees)

        // then
        let expected: WorktreeRegistryError = hidingProject ? .projectNotVisible : .cancelled
        await #expect(throws: expected) { try await lookup.value }
    }

    @Test
    func `given a failed checkout when a sibling is refreshed then the failure is retained without scanning its checkout again`() async throws {
        // given
        let unavailable = RepositoryLocation(path: "/worktrees/offline-copy")
        let scenario = Scenario(worktrees: [RepositoryLocation(path: "/repo"), unavailable])
        await scenario.git.refuseCommands(in: unavailable, with: .commandFailed(
            command: .headCommit, exitCode: 128, standardError: "checkout temporarily unreadable"
        ))
        let original = try await scenario.sut.snapshot(inProject: nil, refreshing: false, allowPartial: true)
        let commandsBeforeRefresh = await scenario.git.received.count

        // when
        await scenario.sut.refresh(in: [WorktreeID(canonicalPath: "/repo")])

        // then
        let refreshed = try await scenario.sut.snapshot(inProject: nil, refreshing: false, allowPartial: true)
        #expect(refreshed.issues == original.issues)
        #expect(refreshed.issues.map(\.reason) == [.gitFailure])
        #expect(await scenario.git.locations.dropFirst(commandsBeforeRefresh).contains(unavailable) == false)
    }

    @Test
    func `given a hidden project when retry is requested then Git receives no command`() async {
        // given
        let scenario = Scenario()
        let project = ProjectID(canonicalPath: "/repo")
        await scenario.store.setProjectVisible(false, id: project)

        // when - then
        await #expect(throws: WorktreeRegistryError.projectNotVisible) { try await scenario.sut.retry(.project(project)) }
        #expect(await scenario.git.received.isEmpty)
    }

    @Test
    func `given an unknown checkout when retry is requested then Git receives no command`() async {
        // given
        let scenario = Scenario()
        let missing = WorktreeID(canonicalPath: "/worktrees/unknown")

        // when - then
        await #expect(throws: WorktreeRegistryError.notFound) { try await scenario.sut.retry(.worktree(missing)) }
        #expect(await scenario.git.received.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a retry whose project lookup is suspended when observation stops then the retry cannot start Git`() async {
        // given
        let scenario = Scenario()
        let project = ProjectID(canonicalPath: "/repo")
        await scenario.store.pauseNextStateRead()
        let retry = Task { try await scenario.sut.retry(.project(project)) }
        await scenario.store.waitUntilStateReadPaused()

        // when
        await scenario.sut.stop()
        await scenario.store.resumeStateRead()

        // then
        await #expect(throws: WorktreeRegistryError.cancelled) { try await retry.value }
        #expect(await scenario.git.received.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)), arguments: [false, true])
    func `given an observer scan is waiting for projects when observation stops then it does not start Git`(
        reconcilingInventory: Bool
    ) async {
        // given
        let scenario = Scenario()
        await scenario.store.pauseNextStateRead()
        let update = Task {
            if reconcilingInventory {
                await scenario.sut.reconcile()
            } else {
                await scenario.sut.refresh(in: [WorktreeID(canonicalPath: "/repo")])
            }
        }
        await scenario.store.waitUntilStateReadPaused()

        // when
        await scenario.sut.stop()
        await scenario.store.resumeStateRead()
        await update.value

        // then
        #expect(await scenario.git.received.isEmpty)
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
