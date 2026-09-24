import Foundation
import Testing

import ClientConnectionDomain
import CoreDiffDomain
import CoreReviewDomain
import ServerGitDomain
import ServerStoreDomain
import ServerWorktreesDomain

@testable import ServerApiPresentation
@testable import ServerReaderData

/// The merged Mac app's local path, driven against the same wiring the routes answer from.
///
/// **This is the test the merge exists for.** Issue #97's whole argument is that a reader on the Mac
/// holding the worktrees should reach them through the protocol seam rather than through a socket —
/// and the risk in that is not the socket, it is two readers that slowly stop agreeing. Both halves
/// here share one `WorktreeReader` over one fixture repository, so a change that moved behaviour
/// back into a route handler would show up as a disagreement rather than as nothing at all.
///
/// The real git binary, the real document, the repositories `make fixtures` built.
@Suite(.serialized)
struct LocalReaderAgreementTests {

    @Test
    func `given an enabled project when this Mac reads its own worktrees then it sees what the routes serve`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)

        // when
        let locally = try await sut.worktrees(inProject: nil)
        let served = try await scenario.reader.worktrees(inProject: nil)

        // then
        #expect(locally.isEmpty == false)
        #expect(locally.map(\.id) == served.map(\.id))
        #expect(locally.map(\.displayName) == served.map(\.displayName))
    }

    @Test
    func `given a worktree with changes when this Mac reads them then the stats and files arrive`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first { $0.stats != .zero })

        // when
        let changes = try await sut.changes(in: worktree.id)

        // then
        #expect(changes.files.isEmpty == false)
        #expect(changes.stats == worktree.stats)
    }

    @Test
    func `given a changed file when this Mac reads its diff then the hunks arrive parsed`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first { $0.stats != .zero })
        let file = try #require(await sut.changes(in: worktree.id).files.first)

        // when
        let diffs = try await sut.diffs(of: [file.id], in: worktree.id, contextLines: 3)

        // then
        let only = try #require(diffs.first)
        #expect(diffs.count == 1)
        #expect(only.file.id == file.id)
        #expect(only.hunks.isEmpty == false)
    }

    @Test
    func `given a changed file when this Mac reads lines around it then a window comes back`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first { $0.stats != .zero })
        let file = try #require(await sut.changes(in: worktree.id).files.first)

        // when
        let read = try await sut.lines(of: file.id, in: worktree.id, side: .new, start: 1, count: 5)

        // then
        #expect(read.lines.isEmpty == false)
    }

    @Test
    func `given a worktree when this Mac pins it then the answer carries the pin`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first)

        // when
        let updated = try await sut.update(
            worktree.id,
            with: WorktreePatch(alias: .set("read on the train"), isPinned: true)
        )

        // then — answered from the one worktree it wrote to rather than by reading the Mac again,
        // which is the difference between a rename taking a moment and taking minutes.
        #expect(updated.isPinned)
        #expect(updated.alias == "read on the train")
        #expect(updated.displayName == "read on the train")
    }

    @Test
    func `given a file this Mac has read when it is marked viewed then the mark is against that content`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first { $0.stats != .zero })
        let file = try #require(await sut.changes(in: worktree.id).files.first)

        // when
        try await sut.markViewed(
            true,
            file: file.id,
            contentHash: file.contentHash,
            in: worktree.id
        )

        // then
        let marks = await scenario.store.state().viewed[worktree.id] ?? [:]
        #expect(marks[file.id]?.contentHash == file.contentHash)
    }

    @Test
    func `given a file that has changed since it was read when it is marked viewed then this Mac refuses`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first { $0.stats != .zero })
        let file = try #require(await sut.changes(in: worktree.id).files.first)

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            try await sut.markViewed(
                true,
                file: file.id,
                contentHash: "a hash nobody read",
                in: worktree.id
            )
        }

        // then — refused rather than applied: a mark over a version nobody saw is the one way this
        // feature can actively mislead someone.
        #expect(failure == .staleContentHash)
    }

    @Test
    func `given a review when this Mac writes it then it reads back what it wrote`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first)
        let comment = ReviewComment(
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

        // when
        try await sut.putReview([comment], in: worktree.id)

        // then
        #expect(try await sut.review(in: worktree.id) == [comment])
    }

    @Test
    func `given the primary checkout when this Mac is asked to delete it then it refuses before git does`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let primary = try #require(await sut.worktrees(inProject: nil).first { $0.isPrimary })

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            try await sut.delete(primary.id)
        }

        // then — git refuses it too, so this is a better sentence rather than the only guard.
        #expect(failure == .worktreeNotDeletable(
            message: "that is the project's own checkout rather than one of its worktrees"
        ))
    }

    @Test
    func `given more files than one read carries when diffs are asked for then this Mac refuses`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first)
        let tooMany = (0...WorktreeReader.maximumBatchedFiles).map { FileID(rawValue: "\($0)") }

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            try await sut.diffs(of: tooMany, in: worktree.id, contextLines: 3)
        }

        // then
        #expect(failure == .tooLarge)
    }

    @Test
    func `given an enabled project when this Mac lists projects then it counts what git found`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)

        // when
        let projects = try await sut.projects()

        // then
        let only = try #require(projects.first)
        #expect(projects.count == 1)
        #expect(only.worktreeCount > 0)
    }

    @Test
    func `given worktrees this Mac no longer has when the store is pruned then their marks go`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let absent = WorktreeID(canonicalPath: "/Users/davide/nowhere")
        try await scenario.store.setViewed(
            true,
            file: FileID(rawValue: "a"),
            in: absent,
            contentHash: "h",
            at: Date(timeIntervalSince1970: 1_800_000_000)
        )

        // when
        await scenario.reader.pruneStore()

        // then
        #expect(await scenario.store.state().viewed[absent] == nil)
    }

    @Test
    func `given a worktree with uncommitted work when this Mac deletes it then it goes and its branch stays`() async throws {
        // given — a repository this test owns, because the shared fixtures are read by the rest of
        // the suite and taking a checkout out from under them surfaces a run later, somewhere that
        // changed nothing.
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let doomed = WorktreeID(canonicalPath: repository.worktree.path)

        // when
        try await sut.delete(doomed)

        // then
        #expect(FileManager.default.fileExists(atPath: repository.worktree.path) == false)
        let remaining = try await sut.worktrees(inProject: nil)
        #expect(remaining.contains { $0.id == doomed } == false)
    }

    @Test
    func `given a changed picture when this Mac reads a side then the bytes come back whole`() async throws {
        // given — two PNG signatures with different tails, over a repository this test owns.
        let committed = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0xC0, 0xFF, 0xEE])
        let working = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x7F, 0x80, 0xFE])
        let repository = try DisposableRepository()
        defer { repository.cleanUp() }
        try repository.commit("Apps/Snapshots/home.png", bytes: committed, message: "add a picture")
        try repository.write("Apps/Snapshots/home.png", bytes: working)
        let scenario = try ApiScenario(at: repository.location)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first(where: \.isPrimary))
        let picture = try #require(
            await sut.changes(in: worktree.id).files.first { $0.path.hasSuffix("home.png") }
        )

        // when
        let read = (
            old: try await sut.image(of: picture.id, in: worktree.id, side: .old),
            new: try await sut.image(of: picture.id, in: worktree.id, side: .new)
        )

        // then — byte for byte on both sides, with no wire to survive. The local path reads the
        // working copy off the disk it is running from and the committed side out of git.
        #expect(read.old == committed)
        #expect(read.new == working)
    }

    // MARK: - A file this worktree did not change

    @Test
    func `given a file not in the changes when its lines are asked for then this Mac says it is gone`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first { $0.stats != .zero })

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            try await sut.lines(
                of: FileID(rawValue: "never changed"),
                in: worktree.id,
                side: .new,
                start: 1,
                count: 5
            )
        }

        // then
        #expect(failure == .fileGone)
    }

    @Test
    func `given a file not in the changes when it is marked viewed then this Mac says it is gone`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first { $0.stats != .zero })

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            try await sut.markViewed(
                true,
                file: FileID(rawValue: "never changed"),
                contentHash: "h",
                in: worktree.id
            )
        }

        // then
        #expect(failure == .fileGone)
    }

    @Test
    func `given a file that is not a picture when its bytes are asked for then this Mac refuses`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first { $0.stats != .zero })
        let text = try #require(
            await sut.changes(in: worktree.id).files.first { $0.path.hasSuffix(".swift") }
        )

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            _ = try await sut.image(of: text.id, in: worktree.id, side: .new)
        }

        // then — refused on what the path claims rather than on what git called binary, which is
        // the same rule the phone applies.
        #expect(failure == .badRequest(message: "that file is not a picture this Mac can serve"))
    }

    @Test
    func `given a file not in the changes when its picture is asked for then this Mac says it is gone`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let worktree = try #require(await sut.worktrees(inProject: nil).first { $0.stats != .zero })

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            _ = try await sut.image(of: FileID(rawValue: "never changed"), in: worktree.id, side: .new)
        }

        // then
        #expect(failure == .fileGone)
    }

    // MARK: - A directory that went away between the enumeration and the read

    @Test
    func `given a worktree whose directory has gone when it is asked about then this Mac says so`() async throws {
        // given — git still lists it, because nothing has pruned it yet. That is the ordinary way
        // this happens rather than the exceptional one: an agent removes a checkout every day.
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.readerWithoutDirectories())
        let worktree = try #require(await LocalGranitaRepository(reader: scenario.reader)
            .worktrees(inProject: nil).first)

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            _ = try await sut.changes(in: worktree.id)
        }

        // then
        #expect(failure == .worktreeGone)
    }

    // MARK: - Every read that names a worktree

    /// One call into the repository, named so a failure says which read disagreed.
    struct WorktreeRead: CustomTestStringConvertible, Sendable {

        let testDescription: String
        let run: @Sendable (LocalGranitaRepository, WorktreeID) async throws -> Void
    }

    /// **One test rather than nine, because the invariant is that they agree.** A reader must get
    /// the same answer from every route into a worktree that is not there, and the way that breaks
    /// is one method resolving where the others do not — the review pair is where it is easiest to
    /// leave out, since neither needs the worktree for anything else.
    @Test(arguments: LocalReaderAgreementTests.everyWorktreeRead)
    func `given a worktree this Mac does not serve when it is asked about then every read refuses the same way`(
        read: WorktreeRead
    ) async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let absent = WorktreeID(canonicalPath: "/Users/davide/nowhere")

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            try await read.run(sut, absent)
        }

        // then
        #expect(failure == .worktreeGone)
    }

    static let everyWorktreeRead: [WorktreeRead] = [
        WorktreeRead(testDescription: "update") { sut, id in
            _ = try await sut.update(id, with: WorktreePatch(alias: .unchanged, isPinned: true))
        },
        WorktreeRead(testDescription: "delete") { sut, id in
            try await sut.delete(id)
        },
        WorktreeRead(testDescription: "changes") { sut, id in
            _ = try await sut.changes(in: id)
        },
        WorktreeRead(testDescription: "diffs") { sut, id in
            _ = try await sut.diffs(of: [FileID(rawValue: "a")], in: id, contextLines: 3)
        },
        WorktreeRead(testDescription: "diff") { sut, id in
            _ = try await sut.diffs(of: [FileID(rawValue: "a")], in: id, contextLines: 3)
        },
        WorktreeRead(testDescription: "lines") { sut, id in
            _ = try await sut.lines(
                of: FileID(rawValue: "a"),
                in: id,
                side: .new,
                start: 1,
                count: 10
            )
        },
        WorktreeRead(testDescription: "image") { sut, id in
            _ = try await sut.image(of: FileID(rawValue: "a"), in: id, side: .new)
        },
        WorktreeRead(testDescription: "markViewed") { sut, id in
            try await sut.markViewed(true, file: FileID(rawValue: "a"), contentHash: "h", in: id)
        },
        WorktreeRead(testDescription: "review") { sut, id in
            _ = try await sut.review(in: id)
        },
        WorktreeRead(testDescription: "putReview") { sut, id in
            try await sut.putReview([], in: id)
        }
    ]

    // MARK: - The read route

    @Test
    func `given this Mac is the source when worktrees are read then only the reading stage is reported`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let sut = LocalGranitaRepository(reader: scenario.reader)
        let recorded = StageRecorder()

        // when
        _ = try await sut.worktrees(inProject: nil) { stage in
            await recorded.append(stage)
        }

        // then — there is no Mac to find and no key to check, so a stage naming either would
        // describe a network that is not in the path. `.reading(.unknown)`, which the protocol's
        // default reports, spells "Waiting for your Mac's response" and there is no response.
        #expect(await recorded.stages == [.reading(.thisMac)])
    }

    // MARK: - The review settings, which are this Mac's own and need no worktree

    @Test
    func `given both review settings when only one is changed then the other is left alone`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        let sut = LocalGranitaRepository(reader: scenario.reader)
        #expect(try await sut.reviewSettings() == .unset)
        _ = try await sut.updateReviewSettings(
            ReviewSettingsPatch(openingLine: "Read on the train", identifier: .letters)
        )

        // when — the opening line is not named at all, which is different from naming it as null.
        let updated = try await sut.updateReviewSettings(
            ReviewSettingsPatch(openingLine: nil, identifier: .numbers)
        )

        // then
        #expect(updated.openingLine == "Read on the train")
        #expect(updated.identifier == .numbers)
    }

    @Test
    func `given an opening line when it is named as null then it is cleared rather than left alone`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        let sut = LocalGranitaRepository(reader: scenario.reader)
        _ = try await sut.updateReviewSettings(
            ReviewSettingsPatch(openingLine: "Read on the train", identifier: nil)
        )

        // when
        let updated = try await sut.updateReviewSettings(
            ReviewSettingsPatch(openingLine: .some(nil), identifier: nil)
        )

        // then
        #expect(updated.openingLine == nil)
    }

    // MARK: - Refusals, in the vocabulary a screen reasons in

    @Test(arguments: [
        (WorktreeReadError.projectNotVisible, ApiFailure.projectNotVisible),
        (WorktreeReadError.directoryGone, ApiFailure.worktreeGone),
        (WorktreeReadError.notFound, ApiFailure.worktreeGone),
        (WorktreeReadError.fileNotInChanges, ApiFailure.fileGone),
        (WorktreeReadError.fileUnreadable(reason: "permission denied"), ApiFailure.fileGone),
        (WorktreeReadError.staleContentHash, ApiFailure.staleContentHash),
        (WorktreeReadError.tooManyFiles(limit: 20), ApiFailure.tooLarge),
        (WorktreeReadError.pictureTooLarge, ApiFailure.tooLarge),
        (WorktreeReadError.cancelled, ApiFailure.cancelled),
        (
            WorktreeReadError.notSaved(reason: "the disk is full"),
            ApiFailure.badRequest(message: "the disk is full")
        ),
        (
            WorktreeReadError.notAPicture,
            ApiFailure.badRequest(message: "that file is not a picture this Mac can serve")
        ),
        (
            WorktreeReadError.notDeletable,
            ApiFailure.worktreeNotDeletable(
                message: "that is the project's own checkout rather than one of its worktrees"
            )
        ),
        (
            WorktreeReadError.gitUnknown(description: "something else threw"),
            ApiFailure.gitFailure(message: "something else threw")
        ),
        (
            WorktreeReadError.git(.timedOut(command: .worktreeStatus)),
            ApiFailure.gitFailure(message: "git took too long and was stopped")
        )
    ])
    func `given this Mac refuses when it is put to a screen then it keeps the meaning the wire gives it`(
        refusal: WorktreeReadError,
        expected: ApiFailure
    ) {
        // given - when
        let failure = ApiFailure(refusal)

        // then
        #expect(failure == expected)
    }

    @Test(arguments: [
        (
            GitError.workingDirectoryUnreadable(
                location: RepositoryLocation(path: "/Users/davide/granita"),
                reason: "no such directory"
            ),
            ApiFailure.worktreeGone
        ),
        (
            GitError.timedOut(command: .worktreeStatus),
            ApiFailure.gitFailure(message: "git took too long and was stopped")
        ),
        (
            GitError.gitUnavailable(reason: "no such file"),
            ApiFailure.gitFailure(message: "git could not be run: no such file")
        ),
        (
            GitError.commandFailed(
                command: .worktreeStatus,
                exitCode: 128,
                standardError: "not a git repository"
            ),
            ApiFailure.gitFailure(message: "git exited 128: not a git repository")
        ),
        (
            GitError.terminatedBySignal(
                command: .worktreeStatus,
                signal: 9,
                standardError: "killed"
            ),
            ApiFailure.gitFailure(message: "git died on signal 9: killed")
        )
    ])
    func `given git refuses when it is put to a screen then an unreadable directory is a worktree that has gone`(
        failure: GitError,
        expected: ApiFailure
    ) {
        // given - when
        let mapped = ApiFailure(failure)

        // then — the one that is not a git failure at all: "git failed" would send the reader
        // looking for a broken toolchain when the directory is simply no longer there.
        #expect(mapped == expected)
    }

    private actor StageRecorder {
        private(set) var stages: [WorktreeReadStage] = []

        func append(_ stage: WorktreeReadStage) {
            stages.append(stage)
        }
    }
}
