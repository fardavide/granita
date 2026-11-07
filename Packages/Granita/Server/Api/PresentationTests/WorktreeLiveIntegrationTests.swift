import Foundation
import Testing

import ClientConnectionDomain
import CoreApiDomain
import CoreDiffDomain
import ServerReaderData
import ServerWatchData
import ServerWorktreesDomain

@Suite("Live worktree integration")
struct WorktreeLiveIntegrationTests {

    @Test(.timeLimit(.minutes(1)))
    func `given a warm local reader when a real source file changes then native observation publishes the same prepared HTTP snapshot`() async throws {
        // given
        let scenario = try Scenario()
        defer { scenario.cleanUp() }
        try scenario.repository.commit("Review.swift", bytes: Data("old\n".utf8), message: "baseline")
        try scenario.repository.write("Review.swift", bytes: Data("first\n".utf8))
        try await scenario.api.enableProject()
        let before = try await scenario.local.readWorktrees(inProject: nil, refreshing: false, reporting: { _ in })
        let previous: WorktreeSnapshot
        switch before {
        case .prepared(let snapshot): previous = snapshot
        case .uncached: throw LiveFixtureFailure.missingPreparedRead
        }
        let primary = try #require(previous.worktrees.first { $0.isPrimary })
        var updates = await scenario.local.updates().makeAsyncIterator()

        // when
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { await scenario.observation.run() }
            defer { group.cancelAll() }
            await scenario.source.waitUntilInstalled()
            try scenario.repository.write("Review.swift", bytes: Data("second\nthird\n".utf8))
            var changed: WorktreeSnapshot?
            while let update = await updates.next() {
                if case .snapshot(let snapshot) = update,
                   snapshot.worktrees.first(where: { $0.id == primary.id })?.stats.insertions == 2 {
                    changed = snapshot
                    break
                }
            }

            // then
            let received = try #require(changed)
            let refreshed = try #require(received.worktrees.first { $0.id == primary.id })
            #expect(refreshed.revision != primary.revision)
            #expect(received.scannedAt >= previous.scannedAt)
            let remote = try await scenario.api.get(WorktreeSnapshot.self, "/v1/worktree-snapshot")
            #expect(remote.worktrees.map(\.id) == received.worktrees.map(\.id))
            for row in remote.worktrees {
                let expected = try #require(received.worktrees.first { $0.id == row.id })
                #expect(row.revision == expected.revision)
                #expect(row.stats == expected.stats)
                #expect(row.lastModified.timeIntervalSince1970 == expected.lastModified.timeIntervalSince1970.rounded(.down))
            }
            #expect(remote.scannedAt.timeIntervalSince1970 == received.scannedAt.timeIntervalSince1970.rounded(.down))
            await scenario.observation.stop()
        }
    }

    private struct Scenario {
        let repository: DisposableRepository
        let api: ApiScenario
        let local: LocalGranitaRepository
        let source: FakeWorktreeObservationSource
        let observation: WorktreeObservation

        init() throws {
            repository = try DisposableRepository()
            api = try ApiScenario(at: repository.location)
            local = LocalGranitaRepository(reader: api.reader)
            source = FakeWorktreeObservationSource(wrapped: FileSystemWorktreeObservationSource())
            observation = WorktreeObservation(
                registry: api.registry,
                git: api.git,
                source: source,
                store: api.store,
                onFailure: { Issue.record("Observation failed: \($0)") }
            )
        }

        func cleanUp() {
            api.cleanUp()
            repository.cleanUp()
        }
    }
}

private enum LiveFixtureFailure: Error {
    case missingPreparedRead
}
