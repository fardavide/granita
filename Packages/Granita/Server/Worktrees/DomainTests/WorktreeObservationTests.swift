import Foundation
import Testing

import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain
@testable import ServerWorktreesDomain

@Suite("Worktree observation lifecycle")
struct WorktreeObservationTests {
    @Test
    func `given an aliased checkout path when observation starts then canonical checkout and Git roots are watched`() async {
        // given
        let scenario = Scenario()

        // when
        let running = Task { await scenario.sut.run() }
        let watched = await scenario.source.nextWatch()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(watched.map(Set.init) == [
            RepositoryLocation(path: "/canonical/project"),
            RepositoryLocation(path: "/canonical/project/.git")
        ])
    }

    @Test
    func `given a watched source file when an event arrives then its worktree refreshes after coalescing`() async {
        // given
        let scenario = Scenario()
        let running = Task { await scenario.sut.run() }
        _ = await scenario.source.nextWatch()
        await scenario.registry.nextReconciliation()
        await scenario.timing.advance(by: .seconds(2))

        // when
        await scenario.source.send(.changed([RepositoryLocation(path: "/canonical/project/Sources/Reader.swift")]))
        let delay = await scenario.timing.nextSleep()
        await scenario.timing.advance(by: .milliseconds(400))
        let refreshed = await scenario.registry.nextRefresh()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(delay == .milliseconds(400))
        #expect(refreshed == [WorktreeID(canonicalPath: "/canonical/project")])
    }

    @Test(.timeLimit(.minutes(1)))
    func `given running observation when a stored alias changes then the cached overlay is published`() async {
        // given
        let scenario = Scenario()
        let running = Task { await scenario.sut.run() }
        _ = await scenario.source.nextWatch()
        await scenario.registry.nextReconciliation()
        await scenario.store.nextSubscription()

        // when
        await scenario.store.setAlias("Ready to review", for: WorktreeID(canonicalPath: "/canonical/project"))
        let published = await scenario.registry.nextStoreChange()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(published)
    }

    @Test
    func `given running observation when reconciliation is requested then its inventory is scanned again`() async {
        // given
        let scenario = Scenario()
        let running = Task { await scenario.sut.run() }
        _ = await scenario.source.nextWatch()
        await scenario.registry.nextReconciliation()
        await scenario.timing.advance(by: .seconds(2))

        // when
        await scenario.sut.reconcile()
        let delay = await scenario.timing.nextSleep()
        await scenario.timing.advance(by: .milliseconds(400))
        await scenario.registry.nextReconciliation()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(delay == .milliseconds(400))
    }

    @Test
    func `given no enabled folders when observation runs then native watching stays idle`() async {
        // given
        let scenario = Scenario(locations: [])

        // when
        let running = Task { await scenario.sut.run() }
        await scenario.store.nextSubscription()
        await scenario.registry.nextReconciliation()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(await scenario.source.watched.isEmpty)
    }

    @Test
    func `given changed inventory when reconciling then replacement roots are watched before the final scan`() async {
        // given
        let scenario = Scenario()
        let running = Task { await scenario.sut.run() }
        _ = await scenario.source.nextWatch()
        await scenario.registry.nextReconciliation()
        await scenario.timing.advance(by: .seconds(2))
        await scenario.registry.replaceLocations([RepositoryLocation(path: "/external")])
        await scenario.git.answer(.repositoryRoot, with: Data("/external\n".utf8))
        await scenario.git.answer(.gitDirectory, with: Data("/external/.git\n".utf8))
        await scenario.git.answer(.commonGitDirectory, with: Data("/external/.git\n".utf8))

        // when
        await scenario.sut.reconcile()
        _ = await scenario.timing.nextSleep()
        await scenario.timing.advance(by: .milliseconds(400))
        await scenario.registry.nextReconciliation()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(await scenario.source.watched.last == [
            RepositoryLocation(path: "/external"),
            RepositoryLocation(path: "/external/.git")
        ])
    }

    @Test(.timeLimit(.minutes(1)))
    func `given idle observation when a folder is enabled then watching starts automatically`() async {
        // given
        let scenario = Scenario(locations: [])
        let running = Task { await scenario.sut.run() }
        await scenario.store.nextSubscription()
        await scenario.registry.nextReconciliation()
        await scenario.registry.replaceLocations([RepositoryLocation(path: "/project")])

        // when
        await scenario.store.add(project: StoredProject(
            id: ProjectID(canonicalPath: "/project"), path: "/project", name: "Granita", isVisible: true
        ))
        _ = await scenario.timing.nextSleep()
        await scenario.timing.advance(by: .milliseconds(400))
        let watched = await scenario.source.nextWatch()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(watched == [
            RepositoryLocation(path: "/canonical/project"),
            RepositoryLocation(path: "/canonical/project/.git")
        ])
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a refreshed inventory when a new checkout appears then its roots are watched automatically`() async {
        // given
        let scenario = Scenario()
        let running = Task { await scenario.sut.run() }
        _ = await scenario.source.nextWatch()
        await scenario.registry.nextReconciliation()
        await scenario.registry.nextSubscription()
        await scenario.timing.advance(by: .seconds(2))
        await scenario.git.answer(.repositoryRoot, with: Data("/external/agent\n".utf8))
        await scenario.git.answer(.gitDirectory, with: Data("/project/.git/worktrees/agent\n".utf8))
        await scenario.git.answer(.commonGitDirectory, with: Data("/project/.git\n".utf8))

        // when
        await scenario.registry.publishLocations([RepositoryLocation(path: "/external/agent")])
        _ = await scenario.timing.nextSleep()
        await scenario.timing.advance(by: .milliseconds(400))
        let watched = await scenario.source.nextWatch()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(watched == [
            RepositoryLocation(path: "/external/agent"),
            RepositoryLocation(path: "/project/.git"),
            RepositoryLocation(path: "/project/.git/worktrees/agent")
        ])
    }

    @Test(.timeLimit(.minutes(1)))
    func `given native watching initially fails when its retry delay ends then watching recovers`() async {
        // given
        let scenario = Scenario(sourceFailures: [.couldNotStartStream])
        let running = Task { await scenario.sut.run() }
        let initial = await scenario.source.nextWatch()
        var failures = scenario.failures.makeAsyncIterator()
        let reported = await failures.next()

        // when
        let delay = await scenario.timing.nextSleep()
        await scenario.timing.advance(by: .seconds(1))
        let retried = await scenario.source.nextWatch()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(reported == .couldNotStartStream)
        #expect(delay == .seconds(1))
        #expect(retried == initial)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given an unreadable project when other roots are healthy then their watching still starts`() async {
        // given
        let missing = RepositoryLocation(path: "/missing")
        let failure = GitError.workingDirectoryUnreadable(location: missing, reason: "Volume is not mounted")
        let scenario = Scenario(
            locations: [missing, RepositoryLocation(path: "/project")],
            discoveryFailures: [missing: failure]
        )
        let running = Task { await scenario.sut.run() }

        // when
        let watched = await scenario.source.nextWatch()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(watched == [
            RepositoryLocation(path: "/canonical/project"),
            RepositoryLocation(path: "/canonical/project/.git")
        ])
    }

    @Test
    func `given startup just scanned a worktree when a file event arrives then the next scan respects its rate limit`() async {
        // given
        let scenario = Scenario()
        let running = Task { await scenario.sut.run() }
        _ = await scenario.source.nextWatch()
        await scenario.registry.nextReconciliation()
        await scenario.timing.advance(by: .milliseconds(500))

        // when
        await scenario.source.send(.changed([RepositoryLocation(path: "/canonical/project/Reader.swift")]))
        let delay = await scenario.timing.nextSleep()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(delay == .milliseconds(1_500))
    }

    @Test
    func `given repeated native failures when observation retries then delays grow to a bounded limit`() async {
        // given
        let delays: [Duration] = [.seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(16), .seconds(30), .seconds(30)]
        let scenario = Scenario(sourceFailures: Array(repeating: .couldNotStartStream, count: delays.count))
        let running = Task { await scenario.sut.run() }
        var failures = scenario.failures.makeAsyncIterator()
        var observed: [Duration?] = []

        // when
        for delay in delays {
            _ = await scenario.source.nextWatch()
            _ = await failures.next()
            observed.append(await scenario.timing.nextSleep())
            await scenario.timing.advance(by: delay)
        }
        _ = await scenario.source.nextWatch()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(observed == delays.map(Optional.some))
    }

    @Test(.timeLimit(.minutes(1)))
    func `given teardown is still running when another run is requested then new watching is not admitted`() async {
        // given
        let scenario = Scenario()
        let running = Task { await scenario.sut.run() }
        _ = await scenario.source.nextWatch()
        await scenario.registry.nextReconciliation()
        await scenario.registry.pauseStopping()
        let stopping = Task { await scenario.sut.stop() }
        await scenario.registry.waitUntilStopping()

        // when
        let restarting = Task { await scenario.sut.run() }
        await withTaskCancellationHandler {
            await restarting.value
        } onCancel: {
            restarting.cancel()
        }
        await scenario.registry.resumeStopping()
        await stopping.value
        await running.value

        // then
        #expect(await scenario.source.watched.count == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given Git discovery temporarily fails when the folder returns then watching recovers automatically`() async {
        // given
        let location = RepositoryLocation(path: "/project")
        let failure = GitError.workingDirectoryUnreadable(location: location, reason: "Volume is not mounted")
        let scenario = Scenario(discoveryFailures: [location: failure])
        let running = Task { await scenario.sut.run() }
        var failures = scenario.failures.makeAsyncIterator()
        _ = await failures.next()

        // when
        let retryDelay = await scenario.timing.nextSleep()
        await scenario.git.allowCommands(in: location)
        await scenario.timing.advance(by: .seconds(1))
        let coalescingDelay = await scenario.timing.nextSleep()
        await scenario.timing.advance(by: .milliseconds(400))
        let watched = await scenario.source.nextWatch()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(retryDelay == .seconds(1))
        #expect(coalescingDelay == .milliseconds(400))
        #expect(watched == [
            RepositoryLocation(path: "/canonical/project"),
            RepositoryLocation(path: "/canonical/project/.git")
        ])
    }

    @Test(.timeLimit(.minutes(1)))
    func `given one project remains unreadable when discovery retries then healthy watching and scans stay untouched`() async {
        // given
        let missing = RepositoryLocation(path: "/missing")
        let failure = GitError.workingDirectoryUnreadable(location: missing, reason: "Volume is not mounted")
        let scenario = Scenario(
            locations: [missing, RepositoryLocation(path: "/project")],
            discoveryFailures: [missing: failure]
        )
        let running = Task { await scenario.sut.run() }
        _ = await scenario.source.nextWatch()
        await scenario.registry.nextReconciliation()
        var failures = scenario.failures.makeAsyncIterator()
        _ = await failures.next()

        // when
        let firstDelay = await scenario.timing.nextSleep()
        await scenario.timing.advance(by: .seconds(1))
        _ = await failures.next()
        let nextDelay = await scenario.timing.nextSleep()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(firstDelay == .seconds(1))
        #expect(nextDelay == .seconds(2))
        #expect(await scenario.source.watched.count == 1)
        #expect(await scenario.registry.reconciliationCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given initial snapshots are unavailable when warming finds an external worktree then its roots are still watched`() async {
        // given
        let scenario = Scenario()
        let external = RepositoryLocation(path: "/external/agent")
        await scenario.registry.finishSnapshots()
        await scenario.registry.discoverOnNextReconciliation([RepositoryLocation(path: "/project"), external])
        await scenario.git.answer(.repositoryRoot, in: external, with: Data("/external/agent\n".utf8))
        await scenario.git.answer(.gitDirectory, in: external, with: Data("/canonical/project/.git/worktrees/agent\n".utf8))
        await scenario.git.answer(.commonGitDirectory, in: external, with: Data("/canonical/project/.git\n".utf8))
        let running = Task { await scenario.sut.run() }
        _ = await scenario.source.nextWatch()
        await scenario.registry.nextReconciliation()

        // when
        let delay = await scenario.timing.nextSleep()
        await scenario.timing.advance(by: .seconds(2))
        let watched = await scenario.source.nextWatch()
        await scenario.sut.stop()
        await running.value

        // then
        #expect(delay == .seconds(2))
        #expect(watched == [
            RepositoryLocation(path: "/canonical/project"),
            RepositoryLocation(path: "/canonical/project/.git"),
            RepositoryLocation(path: "/canonical/project/.git/worktrees/agent"),
            external
        ])
    }

    private struct Scenario {
        let source: FakeWorktreeObservationSource
        let registry: FakeWorktreeObservationRegistry
        let timing: FakeWorktreeObservationTiming
        let store: FakeStore
        let git: FakeGitClient
        let failures: AsyncStream<WorktreeObservationError>
        let sut: WorktreeObservation

        init(
            locations: [RepositoryLocation] = [RepositoryLocation(path: "/project")],
            sourceFailures: [WorktreeObservationError] = [],
            discoveryFailures: [RepositoryLocation: GitError] = [:]
        ) {
            source = FakeWorktreeObservationSource(failures: sourceFailures)
            registry = FakeWorktreeObservationRegistry(locations: locations)
            timing = FakeWorktreeObservationTiming()
            store = FakeStore(projects: [])
            git = FakeGitClient(outputs: [
                .repositoryRoot: Data("/canonical/project\n".utf8),
                .gitDirectory: Data("/canonical/project/.git\n".utf8),
                .commonGitDirectory: Data("/canonical/project/.git\n".utf8)
            ], failures: [:], failuresByLocation: discoveryFailures)
            let reports = AsyncStream.makeStream(of: WorktreeObservationError.self)
            failures = reports.stream
            sut = WorktreeObservation(
                registry: registry,
                git: git,
                source: source,
                store: store,
                onFailure: { failure in
                    reports.continuation.yield(failure)
                    let expected = sourceFailures + discoveryFailures.values.map(WorktreeObservationError.git)
                    if expected.contains(failure) == false {
                        Issue.record("Unexpected observation failure: \(failure)")
                    }
                },
                timing: timing
            )
        }
    }
}
