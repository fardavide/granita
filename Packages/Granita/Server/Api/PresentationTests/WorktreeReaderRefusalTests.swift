import Foundation
import Testing

import CoreDiffDomain
import CoreReviewDomain
import ServerGitData
import ServerGitDomain
import ServerStoreDomain
import ServerWorktreesData
@testable import ServerWorktreesDomain

@Suite("Worktree reader refusals")
struct WorktreeReaderRefusalTests {

    @Test(arguments: MetadataWrite.allCases)
    func `given an unwritable document when reader metadata is saved then the refusal retains its cause`(
        operation: MetadataWrite
    ) async throws {
        // given
        let scenario = Scenario(
            at: try FixtureRepository.renames.location(),
            refusingWrites: .notWritable(reason: "disk is full")
        )
        let rows = try await scenario.reader.worktrees(inProject: nil)
        let worktree = try #require(rows.first)
        let changes = try await scenario.reader.changes(in: worktree.id)
        let file = try #require(changes.files.first)

        // when
        let failure = await #expect(throws: WorktreeReadError.self) {
            switch operation {
            case .alias:
                _ = try await scenario.reader.update(
                    worktree.id, with: WorktreePatch(alias: .set("Review on the train"), isPinned: nil)
                )
            case .pin:
                _ = try await scenario.reader.update(
                    worktree.id, with: WorktreePatch(alias: .unchanged, isPinned: true)
                )
            case .viewed:
                try await scenario.reader.markViewed(
                    true, file: file.id, contentHash: file.contentHash,
                    in: worktree.id, at: Date(timeIntervalSince1970: 1_000)
                )
            case .review:
                try await scenario.reader.putReview([], in: worktree.id)
            case .reviewSettings:
                _ = try await scenario.reader.updateReviewSettings(
                    openingLine: "Review on the train", identifier: .letters
                )
            }
        }

        // then
        guard case .notSaved(let reason) = failure else {
            Issue.record("A refused metadata write must report that it was not saved")
            return
        }
        #expect(reason == "notWritable(reason: \"disk is full\")")
    }

    @Test(arguments: [
        (WorktreeFileError.tooLarge, WorktreeReadError.pictureTooLarge),
        (WorktreeFileError.unreadable(reason: "the picture could not be opened"),
         WorktreeReadError.fileUnreadable(reason: "the picture could not be opened"))
    ])
    func `given a refused working picture when reading it then the reader preserves the reason`(
        fileFailure: WorktreeFileError, expected: WorktreeReadError
    ) async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        try repository.write("preview.png", bytes: Data([0x89, 0x50, 0x4E, 0x47]))
        let scenario = Scenario(at: repository.location, picture: .failure(fileFailure))
        let rows = try await scenario.reader.worktrees(inProject: nil)
        let worktree = try #require(rows.first { $0.isPrimary })

        // when
        let failure = await #expect(throws: WorktreeReadError.self) {
            _ = try await scenario.reader.image(
                of: FileID(repositoryRelativePath: "preview.png"), in: worktree.id, side: .new
            )
        }

        // then
        if case (.pictureTooLarge, .pictureTooLarge) = (expected, failure) { return }
        guard case (.fileUnreadable(let expectedReason), .fileUnreadable(let reason)) = (expected, failure) else {
            Issue.record("The reader must retain the picture refusal's size limit or unreadable cause")
            return
        }
        #expect(reason == expectedReason)
    }

    @Test
    func `given an untracked file when its committed lines are requested then the Git refusal reaches the reader`() async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        try repository.write("new.swift", bytes: Data("let pending = true\n".utf8))
        let scenario = Scenario(at: repository.location)
        let rows = try await scenario.reader.worktrees(inProject: nil)
        let worktree = try #require(rows.first { $0.isPrimary })

        // when
        let failure = await #expect(throws: WorktreeReadError.self) {
            _ = try await scenario.reader.lines(
                of: FileID(repositoryRelativePath: "new.swift"), in: worktree.id,
                side: .old, start: 1, count: 10
            )
        }

        // then
        guard case .git(.commandFailed(_, let exitCode, let diagnostic)) = failure else {
            Issue.record("The failed committed-side read must retain Git's refusal")
            return
        }
        #expect(exitCode == 128)
        #expect(diagnostic.contains("new.swift"))
    }

    @Test
    func `given a cancelled inventory scan when mapping its refusal then the reader retains cancellation`() {
        // given - when
        let refusal = WorktreeReadError(WorktreeRegistryError.cancelled)

        // then
        guard case .cancelled = refusal else {
            Issue.record("An inventory cancellation must remain cancellation at the reader boundary")
            return
        }
    }

    enum MetadataWrite: CaseIterable, Sendable {
        case alias
        case pin
        case viewed
        case review
        case reviewSettings
    }

    private struct Scenario {
        let reader: WorktreeReader

        init(
            at location: RepositoryLocation,
            refusingWrites: StoreError? = nil,
            picture: Result<Data, WorktreeFileError> = .success(Data())
        ) {
            let store = FakeStore(
                projects: [StoredProject(
                    id: ProjectID(canonicalPath: location.path), path: location.path,
                    name: "Reader refusal fixture", isVisible: true
                )],
                failure: refusingWrites
            )
            let service = WorktreeService(
                git: ProcessGitClient(
                    executablePath: "/usr/bin/git",
                    outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
                    timeout: ProcessGitClient.defaultTimeout
                ),
                files: FakeWorktreeFileReading(answer: picture), limits: .standard
            )
            reader = WorktreeReader(
                registry: WorktreeRegistry(
                    store: store, service: service, directory: LocalWorktreeDirectory(),
                    suggestedAliases: { _ in [:] }
                ),
                service: service, store: store
            )
        }
    }
}
