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
import ServerStoreDomain

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

    @Test(arguments: Reader.allCases)
    func `given a healthy checkout when asked for a repair preview then the reader explains it is unavailable`(
        reader: Reader
    ) async throws {
        // given
        let scenario = try Scenario(requiresAuthentication: false)
        defer { scenario.cleanUp() }
        try await scenario.api.enableProject()
        let primary = WorktreeID(canonicalPath: scenario.repository.location.path)
        let address = try #require(URL(string: "https://granita-reader.test:59144"))

        // when - then
        switch reader {
        case .local:
            await #expect(throws: ApiFailure.worktreeGone) {
                try await LocalGranitaRepository(reader: scenario.api.reader).previewWorktreeRepair(primary)
            }
        case .http:
            try await scenario.api.application.test(.router) { client in
                let remote = HttpGranitaRepository(
                    macAt: address,
                    token: PairingToken(rawValue: "unused when authentication is off"),
                    transport: RouterTransport.over(client)
                )
                await #expect(throws: ApiFailure.worktreeGone) {
                    try await remote.previewWorktreeRepair(primary)
                }
            }
        }
        #expect(!FileManager.default.fileExists(atPath: scenario.backups.path))
    }

    @Test
    func `given Git reports a second registration with no link record when previewing then the whole repair is refused`() async throws {
        // given
        let scenario = try Scenario()
        defer { scenario.cleanUp() }
        try await scenario.api.enableProject()
        let metadataRoot = scenario.registrationLink.deletingLastPathComponent().deletingLastPathComponent()
        let incomplete = metadataRoot.appending(path: "incomplete-registration", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: incomplete, withIntermediateDirectories: false)
        let local = LocalGranitaRepository(reader: scenario.api.reader)
        let refusal = ApiFailure.badRequest(message: "Git couldn’t verify that the stale registrations can be removed.")

        // when - then
        await #expect(throws: refusal) {
            try await local.previewWorktreeRepair(scenario.unavailable)
        }
        #expect(FileManager.default.fileExists(atPath: scenario.registrationLink.path))
        #expect(FileManager.default.fileExists(atPath: incomplete.path))
    }

    @Test
    func `given a stale registration when an older local reader requests a complete list then it receives a Git failure`() async throws {
        // given
        let scenario = try Scenario()
        defer { scenario.cleanUp() }
        try await scenario.api.enableProject()
        let local = LocalGranitaRepository(reader: scenario.api.reader)

        // when - then
        await #expect(throws: ApiFailure.gitFailure(message: "Git reports a stale worktree registration")) {
            try await local.worktrees(inProject: nil)
        }
    }

    @Test(arguments: ChangeAfterPreview.allCases)
    func `given the repair can no longer proceed as previewed when it is approved then the registration stays in place`(
        change: ChangeAfterPreview
    ) async throws {
        // given
        let scenario = try Scenario()
        defer { scenario.cleanUp() }
        try await scenario.api.enableProject()
        let reader = LocalGranitaRepository(reader: scenario.api.reader)
        let preview = try await reader.previewWorktreeRepair(scenario.unavailable)
        let registration = try await scenario.apply(change)
        let original = try Data(contentsOf: registration)

        // when - then
        await #expect(throws: change.refusal) {
            try await reader.approveWorktreeRepair(preview.approval)
        }
        #expect(try Data(contentsOf: registration) == original)
    }

    @Test(arguments: Reader.allCases)
    func `given a repair preview has been used once when the same approval is replayed then it is refused`(
        reader: Reader
    ) async throws {
        // given
        let scenario = try Scenario(requiresAuthentication: false)
        defer { scenario.cleanUp() }
        try await scenario.api.enableProject()
        let local = LocalGranitaRepository(reader: scenario.api.reader)
        let preview = try await local.previewWorktreeRepair(scenario.unavailable)
        let repaired = try await local.approveWorktreeRepair(preview.approval)
        #expect(repaired.issues.isEmpty)
        let address = try #require(URL(string: "https://granita-reader.test:59144"))
        let refusal = ApiFailure.badRequest(
            message: "The repair preview changed or expired. Review it again before confirming."
        )

        // when - then
        switch reader {
        case .local:
            await #expect(throws: refusal) {
                try await local.approveWorktreeRepair(preview.approval)
            }
        case .http:
            try await scenario.api.application.test(.router) { client in
                let remote = HttpGranitaRepository(
                    macAt: address,
                    token: PairingToken(rawValue: "unused when authentication is off"),
                    transport: RouterTransport.over(client)
                )
                await #expect(throws: refusal) {
                    try await remote.approveWorktreeRepair(preview.approval)
                }
            }
        }
        let backups = try FileManager.default.contentsOfDirectory(atPath: scenario.backups.path)
        #expect(backups.count == 1)
    }

    @Test
    func `given a checkout is reconnected when the local reader retries it then the recovered row returns`() async throws {
        // given
        let scenario = try Scenario()
        defer { scenario.cleanUp() }
        try await scenario.api.enableProject()
        let local = LocalGranitaRepository(reader: scenario.api.reader)
        let snapshot = try await scenario.api.reader.snapshot(inProject: nil, refreshing: false, allowPartial: true)
        #expect(snapshot.issues.map(\.target) == [.worktree(scenario.unavailable)])
        _ = try await scenario.apply(.reconnected)

        // when
        let recovered = try await local.retryWorktreeScan(.worktree(scenario.unavailable))

        // then
        #expect(recovered.issues.isEmpty)
        #expect(recovered.worktrees.contains { $0.id == scenario.unavailable })
    }

    @Test
    func `given an unknown checkout when the local reader retries it then it explains the worktree is gone`() async throws {
        // given
        let scenario = try Scenario()
        defer { scenario.cleanUp() }
        try await scenario.api.enableProject()
        let local = LocalGranitaRepository(reader: scenario.api.reader)
        let worktree = WorktreeID(rawValue: "removed-before-scan")

        // when - then
        await #expect(throws: ApiFailure.worktreeGone) {
            try await local.retryWorktreeScan(.worktree(worktree))
        }
    }

    enum Reader: CaseIterable, Sendable {
        case local
        case http
    }

    enum ChangeAfterPreview: CaseIterable, Sendable {
        case reconnected
        case projectRenamed
        case staleSetGrew
        case commonDirectoryMoved
        case backupLocationOccupied

        var refusal: ApiFailure {
            switch self {
            case .reconnected, .projectRenamed, .staleSetGrew, .commonDirectoryMoved:
                .badRequest(message: "The repair preview changed or expired. Review it again before confirming.")
            case .backupLocationOccupied:
                .badRequest(message: "Git couldn’t verify that the stale registrations can be removed.")
            }
        }
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

        func apply(_ change: ChangeAfterPreview) async throws -> URL {
            let fileSystem = FileManager.default
            let checkout = URL(filePath: repository.worktree.path, directoryHint: .isDirectory)
            let project = URL(filePath: repository.location.path, directoryHint: .isDirectory)
            let metadata = registrationLink.deletingLastPathComponent()
            switch change {
            case .reconnected:
                let link = checkout.appending(path: ".git")
                try Data("gitdir: \(metadata.path)\n".utf8).write(to: link)
            case .projectRenamed:
                try await api.store.add(project: StoredProject(
                    id: ProjectID(canonicalPath: repository.location.path),
                    path: repository.location.path,
                    name: "Project renamed after preview",
                    isVisible: true
                ))
            case .staleSetGrew:
                let sibling = metadata.deletingLastPathComponent()
                    .appending(path: "new-stale-registration", directoryHint: .isDirectory)
                try fileSystem.copyItem(at: metadata, to: sibling)
                let brokenLink = checkout.appending(path: "other-missing-checkout/.git")
                try Data("\(brokenLink.path)\n".utf8).write(to: sibling.appending(path: "gitdir"))
            case .commonDirectoryMoved:
                let common = project.appending(path: ".git")
                let moved = project.deletingLastPathComponent()
                    .appending(path: "moved-common", directoryHint: .isDirectory)
                try fileSystem.moveItem(at: common, to: moved)
                try Data("gitdir: \(moved.path)\n".utf8).write(to: common)
                return moved.appending(path: "worktrees/worktree/gitdir")
            case .backupLocationOccupied:
                try Data("Existing item\n".utf8).write(to: backups)
            }
            return registrationLink
        }

        func cleanUp() {
            api.cleanUp()
            repository.cleanUp()
        }
    }
}
