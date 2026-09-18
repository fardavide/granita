import Foundation
import Testing

import CoreDiffDomain
import CoreReviewDomain
import ServerGitData
import ServerGitDomain
import ServerStoreData
import ServerStoreDomain
import ServerWorktreesData
import ServerWorktreesDomain
@testable import ServerApiPresentation

/// `SPEC.md` §9's startup housekeeping, which is the only thing that ever drops what a deleted
/// worktree left behind.
///
/// **The case worth the most here is the one that does nothing.** An agent makes and destroys these
/// checkouts, so pruning has to be automatic — and a project that cannot be read looks exactly like
/// a project with no worktrees. Acting on that reading would delete a reader's marks and reviews for
/// being temporarily unreachable, which is the one mistake this pass must never make.
@Suite("Worktree registry pruning")
struct WorktreeRegistryPruningTests {

    @Test
    func `given a worktree that is gone when the store is pruned then its marks and review go too`(
    ) async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try await Scenario(at: repository.location)
        let living = WorktreeID(canonicalPath: repository.worktree.path)
        let deleted = WorktreeID(canonicalPath: "/repo/an-agent-removed-this")
        for worktree in [living, deleted] {
            try await scenario.store.setViewed(
                true,
                file: FileID(repositoryRelativePath: "a.swift"),
                in: worktree,
                contentHash: "h",
                at: Date(timeIntervalSince1970: 1)
            )
            try await scenario.store.setReview([aComment], in: worktree)
        }

        // when
        await scenario.sut.pruneStore()

        // then
        let state = await scenario.store.state()
        #expect(state.viewed[living] != nil)
        #expect(state.viewed[deleted] == nil)
        #expect(state.reviews[living] != nil)
        #expect(state.reviews[deleted] == nil)
    }

    @Test
    func `given more marks than the cap when the store is pruned then the oldest are dropped`(
    ) async throws {
        // given
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try await Scenario(at: repository.location)
        let living = WorktreeID(canonicalPath: repository.worktree.path)
        for index in 0..<4 {
            try await scenario.store.setViewed(
                true,
                file: FileID(repositoryRelativePath: "file\(index).swift"),
                in: living,
                contentHash: "h\(index)",
                at: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        // when
        await scenario.sut.pruneStore(markLimit: 2)

        // then — the two most recently marked, which is what a reader is still working on.
        let marks = await scenario.store.state().viewed[living] ?? [:]
        #expect(marks.count == 2)
        #expect(marks[FileID(repositoryRelativePath: "file3.swift")] != nil)
        #expect(marks[FileID(repositoryRelativePath: "file0.swift")] == nil)
    }

    @Test
    func `given a project that cannot be read when the store is pruned then nothing is dropped`(
    ) async throws {
        // given — a repository on a volume that has not mounted yet answers the same as one with no
        // worktrees. Pruning on that reading would cost a reader their marks for being briefly
        // unreachable, and there is always another launch.
        let scenario = try await Scenario(at: RepositoryLocation(path: "/nowhere/at/all"))
        let worktree = WorktreeID(canonicalPath: "/repo/slice")
        try await scenario.store.setViewed(
            true,
            file: FileID(repositoryRelativePath: "a.swift"),
            in: worktree,
            contentHash: "h",
            at: Date(timeIntervalSince1970: 1)
        )

        // when
        await scenario.sut.pruneStore()

        // then
        #expect(await scenario.store.state().viewed[worktree] != nil)
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut: WorktreeRegistry
        let store: JsonDocumentStore
        private let directory: URL

        init(at location: RepositoryLocation) async throws {
            directory = URL.temporaryDirectory
                .appending(path: "granita-prune-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            store = JsonDocumentStore(
                fileUrl: directory.appending(path: "granita.json", directoryHint: .notDirectory)
            )
            try await store.add(project: StoredProject(
                id: ProjectID(canonicalPath: location.path),
                path: location.path,
                name: "repo",
                isVisible: true
            ))
            sut = WorktreeRegistry(
                store: store,
                service: WorktreeService(
                    git: ProcessGitClient(
                        executablePath: "/usr/bin/git",
                        outputLimitBytes: ProcessGitClient.defaultOutputLimitBytes,
                        timeout: ProcessGitClient.defaultTimeout
                    ),
                    files: LocalWorktreeFiles(),
                    limits: .standard
                ),
                suggestedAliases: { _ in [:] }
            )
        }
    }
}

// MARK: -

private let aComment = ReviewComment(
    anchor: CommentAnchor(
        file: FileID(repositoryRelativePath: "src/a.swift"),
        first: DiffLinePosition(oldNumber: nil, newNumber: 12),
        last: DiffLinePosition(oldNumber: nil, newNumber: 14)
    ),
    path: "src/a.swift",
    lines: CommentedLines(side: .new, first: 12, last: 14),
    language: "swift",
    quotedLines: ["+    let a = 1"],
    text: "This should be a constant."
)
