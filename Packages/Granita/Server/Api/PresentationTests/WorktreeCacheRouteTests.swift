import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

import ClientConnectionData
import ClientConnectionDomain
import CoreApiDomain
import CoreDiffDomain
import ServerGitDomain
import ServerReaderData

@Suite("Worktree cache routes")
struct WorktreeCacheRouteTests {

    @Test(arguments: [Reader.local, .http])
    func `given a missing unscanned project and a stale healthy summary when reading the prepared list then fresh healthy rows arrive uncached`(
        reader: Reader
    ) async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try repository.commit("review.swift", bytes: Data("old\n".utf8), message: "review baseline")
        try repository.write("review.swift", bytes: Data("first\n".utf8))
        try await scenario.enableProject()
        let cached = try await scenario.reader.worktrees(inProject: nil)
        let primary = try #require(cached.first { $0.isPrimary })
        #expect(primary.stats.insertions == 1)
        let missingStoredProject = RepositoryLocation(path: repository.location.path + "/missing-stored-project")
        try await scenario.enableProject(at: missingStoredProject)
        try repository.write("review.swift", bytes: Data("second\nthird\n".utf8))

        // when
        let read: WorktreeRead
        switch reader {
        case .local:
            read = try await LocalGranitaRepository(reader: scenario.reader)
                .readWorktrees(inProject: nil, refreshing: false, reporting: { _ in })
        case .http:
            read = try await scenario.application.test(.router) { client in
                try await HttpGranitaRepository(
                    macAt: try #require(URL(string: "https://granita-reader.test:59144")),
                    token: PairingToken(rawValue: "unused when authentication is off"),
                    transport: RouterTransport.over(client)
                )
                .readWorktrees(inProject: nil, refreshing: false, reporting: { _ in })
            }
        }

        // then
        guard case .uncached(let rows) = read else {
            Issue.record("An incomplete prepared inventory must return uncached healthy rows")
            return
        }
        let refreshed = try #require(rows.first { $0.id == primary.id })
        #expect(refreshed.stats.insertions == 2)
        #expect(refreshed.revision != primary.revision)
    }

    @Test
    func `given a cached linked worktree when the reader deletes it then cached lists and live snapshots omit it immediately`() async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let rows = try await scenario.reader.worktrees(inProject: nil)
        let linked = try #require(rows.first { $0.isPrimary == false })
        var updates = await scenario.reader.updates().makeAsyncIterator()
        _ = await updates.next()

        // when
        try await scenario.reader.delete(linked.id)
        let commandsAfterRemoval = await scenario.git.runs.count
        let remaining = try await scenario.reader.worktrees(inProject: nil)
        await scenario.registry.stop()

        // then
        #expect(remaining.contains { $0.id == linked.id } == false)
        #expect(await scenario.git.runs.count == commandsAfterRemoval)
        let published = try #require(await updates.next())
        #expect(published.worktrees.contains { $0.id == linked.id } == false)
        #expect(await updates.next() == nil)
    }

    @Test
    func `given a prepared local reader when subscribing then its current snapshot reaches the client`() async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let local = LocalGranitaRepository(reader: scenario.reader)
        let prepared = try await local.readWorktrees(inProject: nil, refreshing: false, reporting: { _ in })

        // when
        var updates = await local.updates().makeAsyncIterator()
        let first = await updates.next()
        await scenario.registry.stop()

        // then
        guard case .prepared(let snapshot) = prepared else {
            Issue.record("The local reader did not return a prepared snapshot")
            return
        }
        #expect(first == .snapshot(snapshot))
        #expect(await updates.next() == nil)
    }

    @Test
    func `given a prepared list when its snapshot is requested then the response retains the actual scan date without git`() async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let prepared = try await scenario.get([Worktree].self, "/v1/worktrees")
        let warmedAt = Date()
        let commands = await scenario.git.runs.count

        // when
        let snapshot = try await scenario.get(WorktreeSnapshot.self, "/v1/worktree-snapshot")

        // then
        #expect(snapshot.worktrees == prepared)
        #expect(snapshot.scannedAt <= warmedAt)
        #expect(await scenario.git.runs.count == commands)
    }

    @Test
    func `given a cached summary when refresh is requested then the response reflects current files`() async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try repository.commit("review.swift", bytes: Data("old\n".utf8), message: "review baseline")
        try repository.write("review.swift", bytes: Data("first\n".utf8))
        try await scenario.enableProject()
        let before = try await scenario.get([Worktree].self, "/v1/worktrees")
        let primary = try #require(before.first { $0.isPrimary })

        // when
        try repository.write("review.swift", bytes: Data("second\nthird\n".utf8))
        let refreshed = try await scenario.get([Worktree].self, "/v1/worktrees?refresh=true")

        // then
        let updated = try #require(refreshed.first { $0.id == primary.id })
        #expect(updated.stats.insertions == 2)
        #expect(updated.revision != primary.revision)
    }
    @Test
    func `given a local cached summary when refresh is requested then current files are read`() async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try repository.commit("review.swift", bytes: Data("old\n".utf8), message: "review baseline")
        try repository.write("review.swift", bytes: Data("first\n".utf8))
        try await scenario.enableProject()
        let local = LocalGranitaRepository(reader: scenario.reader)
        _ = try await local.worktrees(inProject: nil)

        // when
        try repository.write("review.swift", bytes: Data("second\nthird\n".utf8))
        let refreshed = try await local.refreshWorktrees(inProject: nil)

        // then
        #expect(refreshed.first { $0.isPrimary }?.stats.insertions == 2)
    }

    @Test
    func `given an unpaired device when it opens live updates then authentication refuses it`() async throws {
        // given
        let scenario = try ApiScenario(repository: .renames, requiresAuthentication: true)
        defer { scenario.cleanUp() }

        // when - then
        try await scenario.application.test(.router) { client in
            try await client.execute(uri: "/v1/events", method: .get) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    enum Reader: Sendable {
        case local
        case http
    }
}
