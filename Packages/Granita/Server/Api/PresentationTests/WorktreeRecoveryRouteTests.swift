import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

import ClientConnectionData
import ClientConnectionDomain
import CoreApiDomain
import CoreDiffDomain
import ServerGitDomain

@Suite("Worktree recovery routes")
struct WorktreeRecoveryRouteTests {

    @Test(arguments: [false, true])
    func `given a stale registration when a cold snapshot is requested then the API honors partial inventory opt in`(
        allowsPartial: Bool
    ) async throws {
        // given
        let scenario = try Scenario(requiresAuthentication: false)
        defer { scenario.cleanUp() }
        try await scenario.api.enableProject()
        let primary = WorktreeID(canonicalPath: scenario.repository.location.path)
        let project = ProjectID(canonicalPath: scenario.repository.location.path)
        let unavailable = scenario.unavailable
        let uri = allowsPartial ? "/v1/worktree-snapshot?allowPartial=true" : "/v1/worktree-snapshot"

        // when - then
        try await scenario.api.application.test(.router) { client in
            try await client.execute(uri: uri, method: .get) { response in
                if allowsPartial {
                    try #require(response.status == .ok)
                    let snapshot = try wireDecoder().decode(WorktreeSnapshot.self, from: Data(buffer: response.body))
                    #expect(snapshot.worktrees.map(\.id) == [primary])
                    let issue = try #require(snapshot.issues.first)
                    #expect(snapshot.issues.count == 1)
                    #expect(issue.target == .worktree(unavailable))
                    #expect(issue.projectID == project)
                    #expect(issue.reason == .staleRegistration)
                    #expect(issue.lastRead == .never)
                } else {
                    #expect(response.status == .internalServerError)
                }
            }
        }
    }

    @Test
    func `given a valid repair preview when an unpaired phone approves it then registrations stay in place`() async throws {
        // given
        let scenario = try Scenario()
        defer { scenario.cleanUp() }
        try await scenario.api.enableProject()
        let preview = try await scenario.api.reader.previewRepair(for: scenario.unavailable)
        let address = try #require(URL(string: "https://granita-reader.test:59144"))

        // when
        try await scenario.api.application.test(.router) { client in
            let reader = HttpGranitaRepository(
                macAt: address,
                token: PairingToken(rawValue: "not a token this Mac issued"),
                transport: RouterTransport.over(client)
            )
            await #expect(throws: ApiFailure.unauthorized) {
                try await reader.approveWorktreeRepair(preview.approval)
            }
        }

        // then
        #expect(!FileManager.default.fileExists(atPath: scenario.backups.path))
        #expect(try scenario.repository.worktreePaths().contains(scenario.repository.worktree.path))
    }

    @Test
    func `given a paired phone previews a stale registration when it approves then only its Git metadata is backed up`() async throws {
        // given
        let scenario = try Scenario()
        defer { scenario.cleanUp() }
        try await scenario.api.enableProject()
        let originalContents = try Data(contentsOf: scenario.uncommittedFile)
        let originalLink = try Data(contentsOf: scenario.registrationLink)
        let invitation = await scenario.api.pairing.invite()
        let address = try #require(URL(string: "https://granita-reader.test:59144"))
        let unavailable = scenario.unavailable

        // when
        let snapshot = try await scenario.api.application.test(.router) { client in
            let transport = RouterTransport.over(client)
            let pair = try await HttpServerPairing(macAt: address, transport: transport)
                .pair(with: invitation.code, as: PairingDevice(name: "Granita Test iPhone", platform: "iOS"))
            let reader = HttpGranitaRepository(macAt: address, token: pair.token, transport: transport)
            let preview = try await reader.previewWorktreeRepair(unavailable)
            #expect(preview.projectName == "project")
            #expect(preview.registrations == ["worktree"])
            return try await reader.approveWorktreeRepair(preview.approval)
        }

        // then
        #expect(snapshot.issues.isEmpty)
        #expect(snapshot.worktrees.map(\.id) == [WorktreeID(canonicalPath: scenario.repository.location.path)])
        #expect(try scenario.repository.worktreePaths() == [scenario.repository.location.path])
        #expect(try scenario.repository.hasBranch(scenario.repository.branch))
        #expect(try Data(contentsOf: scenario.uncommittedFile) == originalContents)
        let backups = try FileManager.default.contentsOfDirectory(at: scenario.backups, includingPropertiesForKeys: nil)
        try #require(backups.count == 1)
        let batch = try #require(backups.first)
        #expect(try Data(contentsOf: batch.appending(path: "worktree/gitdir")) == originalLink)
        #expect(!FileManager.default.fileExists(atPath: scenario.registrationLink.path))
    }

    private struct Scenario {
        let api: ApiScenario
        let repository: DisposableRepository
        let unavailable: WorktreeID
        let uncommittedFile: URL
        let backups: URL
        let registrationLink: URL

        init(requiresAuthentication: Bool = true) throws {
            let repository = try DisposableRepository()
            let checkout = URL(filePath: repository.worktree.path, directoryHint: .isDirectory)
            do {
                try FileManager.default.removeItem(at: checkout.appending(path: ".git", directoryHint: .notDirectory))
                api = try ApiScenario(at: repository.location, requiresAuthentication: requiresAuthentication)
            } catch {
                repository.cleanUp()
                throw error
            }
            self.repository = repository
            unavailable = WorktreeID(canonicalPath: repository.worktree.path)
            uncommittedFile = checkout.appending(path: "wip.txt", directoryHint: .notDirectory)
            let commonDirectory = URL(filePath: repository.location.path).appending(path: ".git", directoryHint: .isDirectory)
            backups = commonDirectory.appending(path: "granita-worktree-backups", directoryHint: .isDirectory)
            registrationLink = commonDirectory.appending(path: "worktrees/worktree/gitdir", directoryHint: .notDirectory)
        }

        func cleanUp() {
            api.cleanUp()
            repository.cleanUp()
        }
    }
}
