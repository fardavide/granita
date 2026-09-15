import Foundation
import Testing

import CoreDiffDomain
import ServerGitDomain
@testable import ServerWorktreesDomain

/// The two sides of a picture come from two different places, and the whole of what can go wrong is
/// that one of them quietly hands over a prefix.
@Suite("Worktree images")
struct WorktreeImageTests {

    // MARK: - Where each side comes from

    @Test
    func `given a committed picture when the old side is read then it comes from the object database`(
    ) async throws {
        // given — bytes that are not text, so nothing downstream can be decoding them by accident.
        let committed = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0xFF])
        let path = RepositoryRelativePath("Apps/Snapshots/home-light.png")
        let scenario = Scenario(committed: [path: committed])

        // when
        let read = try await scenario.sut.imageBytes(of: path, side: .old, in: scenario.location)

        // then
        #expect(read == committed)
        #expect(await scenario.files.received.isEmpty)
    }

    @Test
    func `given a working copy when the new side is read then it comes off the disk rather than git`(
    ) async throws {
        // given — the working copy is not in the object database, so git cannot answer for it.
        let onDisk = Data([0x89, 0x50, 0x4E, 0x47, 0x11, 0x22])
        let path = RepositoryRelativePath("Apps/Snapshots/home-light.png")
        let scenario = Scenario(working: ["Apps/Snapshots/home-light.png": onDisk])

        // when
        let read = try await scenario.sut.imageBytes(of: path, side: .new, in: scenario.location)

        // then
        #expect(read == onDisk)
        #expect(await scenario.files.received.map(\.text) == ["Apps/Snapshots/home-light.png"])
        // The ceiling travels with the request rather than being the reader's own idea of one.
        #expect(await scenario.files.ceilings == [scenario.limits.maximumImageBytes])
    }

    @Test
    func `given a repository with no commits when the old side is read then it compares against the empty tree`(
    ) async throws {
        // given — a project on its first day answers every command normally except the ones naming
        // HEAD, so the substitution has to reach this read too.
        let path = RepositoryRelativePath("art/logo.png")
        let scenario = Scenario(headCommit: "", committed: [path: Data([0x01])])

        // when
        _ = try? await scenario.sut.imageBytes(of: path, side: .old, in: scenario.location)

        // then
        let asked = await scenario.git.received
        #expect(asked.contains(.fileContent(path: path, at: .emptyTree)))
    }

    // MARK: - Refusing rather than trimming

    @Test
    func `given a committed picture the transport cut off when it is read then it is refused whole`(
    ) async throws {
        // given — git exited normally and what came back is a prefix, which for a picture is a
        // decoder drawing nothing under a card claiming it arrived.
        let path = RepositoryRelativePath("Apps/Snapshots/ipad-dark.png")
        let scenario = Scenario(
            committed: [path: Data([0x89, 0x50, 0x4E, 0x47])],
            cutOff: [path]
        )

        // when - then
        await #expect(throws: WorktreeImageError.tooLarge) {
            try await scenario.sut.imageBytes(of: path, side: .old, in: scenario.location)
        }
    }

    @Test
    func `given a committed picture over the ceiling when it is read then it is refused`() async throws {
        // given
        let path = RepositoryRelativePath("art/huge.png")
        let scenario = Scenario(
            committed: [path: Data(repeating: 0x7F, count: 65)],
            limits: .tiny
        )

        // when - then
        await #expect(throws: WorktreeImageError.tooLarge) {
            try await scenario.sut.imageBytes(of: path, side: .old, in: scenario.location)
        }
    }

    @Test
    func `given a working copy over the ceiling when it is read then the reader's refusal is carried`(
    ) async throws {
        // given
        let path = RepositoryRelativePath("art/huge.png")
        let scenario = Scenario(working: ["art/huge.png": Data(repeating: 0x7F, count: 65)], limits: .tiny)

        // when - then
        await #expect(throws: WorktreeImageError.tooLarge) {
            try await scenario.sut.imageBytes(of: path, side: .new, in: scenario.location)
        }
    }

    @Test
    func `given a working copy that cannot be opened when it is read then the reason survives`(
    ) async throws {
        // given — an agent deleting a file mid-read is the ordinary way here, not the exceptional one.
        let scenario = Scenario(failingReads: .unreadable(reason: "no such file or directory"))

        // when - then
        await #expect(throws: WorktreeImageError.unreadable(reason: "no such file or directory")) {
            try await scenario.sut.imageBytes(
                of: RepositoryRelativePath("art/gone.png"),
                side: .new,
                in: scenario.location
            )
        }
    }

    @Test
    func `given git refuses the committed side when it is read then git's own words survive`() async throws {
        // given — the committed side of a file that has just arrived is exactly this refusal, and
        // git's sentence is the only thing that makes it diagnosable from a phone.
        let path = RepositoryRelativePath("art/new.png")
        let refusal = GitError.commandFailed(
            command: .fileContent(path: path, at: .head),
            exitCode: 128,
            standardError: "fatal: path 'art/new.png' exists on disk, but not in 'HEAD'"
        )
        let scenario = Scenario(refusing: [.fileContent(path: path, at: .head): refusal])

        // when - then
        await #expect(throws: WorktreeImageError.git(refusal)) {
            try await scenario.sut.imageBytes(of: path, side: .old, in: scenario.location)
        }
    }

    @Test
    func `given git will not say what HEAD is when the old side is read then the refusal reaches the caller`(
    ) async throws {
        // given — the revision is resolved before the blob is asked for, so its failure is its own
        // path out of this method rather than the blob read's.
        let refusal = GitError.workingDirectoryUnreadable(
            location: RepositoryLocation(path: "/repo"),
            reason: "no such directory"
        )
        let scenario = Scenario(refusing: [.headCommit: refusal])

        // when - then
        await #expect(throws: WorktreeImageError.git(refusal)) {
            try await scenario.sut.imageBytes(
                of: RepositoryRelativePath("art/logo.png"),
                side: .old,
                in: scenario.location
            )
        }
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut: WorktreeService
        let git: FakeGitClient
        let files: FakeWorktreeFileReading
        let limits: WorktreeLimits
        let location = RepositoryLocation(path: "/repo")

        init(
            headCommit: String = "abc123\n",
            committed: [RepositoryRelativePath: Data] = [:],
            working: [String: Data] = [:],
            cutOff: [RepositoryRelativePath] = [],
            failingReads: WorktreeFileError? = nil,
            refusing: [GitCommand: GitError] = [:],
            limits: WorktreeLimits = .standard
        ) {
            let revision: GitRevision = headCommit.isEmpty ? .emptyTree : .head
            var outputs: [GitCommand: Data] = [.headCommit: Data(headCommit.utf8)]
            for (path, bytes) in committed {
                outputs[.fileContent(path: path, at: revision)] = bytes
            }
            git = FakeGitClient(
                outputs: outputs,
                failures: refusing,
                truncated: Set(cutOff.map { GitCommand.fileContent(path: $0, at: revision) })
            )
            files = FakeWorktreeFileReading(contents: working, failing: failingReads)
            self.limits = limits
            sut = WorktreeService(git: git, files: files, limits: limits)
        }
    }
}

private extension WorktreeLimits {

    /// Small enough that a test can go over it with a handful of bytes rather than twelve megabytes
    /// of them.
    static let tiny = WorktreeLimits(
        maximumChangedFiles: 1_000,
        maximumDiffLines: 20_000,
        truncatedDiffLines: 2_000,
        maximumImageBytes: 64
    )
}
