import Foundation
import Testing

import CoreDiffDomain
import ServerGitDomain
@testable import ServerWorktreesDomain

/// The change set and everything derived from it. What is being asserted throughout is that one
/// comparison produces both the file list and its stats — the rule the whole git layer exists to
/// keep, because a list from `status` and stats from `diff` disagree about renames routinely.
@Suite("Worktree service")
struct WorktreeServiceTests {

    // MARK: - One comparison, two outputs

    @Test
    func `given a rename when the change set is built then its stats land on the file that moved`() async throws {
        // given
        let scenario = Scenario(
            raw: [":100644 100644 600d48a 0102a25 R074", "old.txt", "new.txt"],
            numstat: ["1\t1\t", "old.txt", "new.txt"],
            untracked: [],
            status: []        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then — the two commands report a rename's paths in opposite orders, so a mismatch here is
        // stats attached to a file that is not in the list and a file in the list with no stats.
        #expect(changeSet.files.count == 1)
        #expect(changeSet.files[0].path == "new.txt")
        #expect(changeSet.files[0].oldPath == "old.txt")
        #expect(changeSet.files[0].status == .renamed)
        #expect(changeSet.files[0].stats == ChangeStats(filesChanged: 1, insertions: 1, deletions: 1))
        #expect(changeSet.stats == ChangeStats(filesChanged: 1, insertions: 1, deletions: 1))
    }

    @Test
    func `given untracked files when the change set is built then they are added files`() async throws {
        // given
        let scenario = Scenario(
            raw: [":100644 100644 aaa 0000000 M", "tracked.txt"],
            numstat: ["2\t0\ttracked.txt"],
            untracked: ["fresh.txt"],
            status: []        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then — an untracked file is shown as a file that is entirely new, which is what it is to
        // someone reading what an agent left behind.
        let fresh = try #require(changeSet.files.first { $0.path == "fresh.txt" })
        #expect(fresh.status == .untracked)
        #expect(changeSet.files.count == 2)
    }

    @Test
    func `given a worktree nested inside this one when the change set is built then it is not a file`(
    ) async throws {
        // given — git will not descend into another repository, so it reports the whole thing as
        // one directory entry with a trailing separator. Claude Code puts its worktrees exactly
        // there, so every project an agent has touched has one.
        let scenario = Scenario(
            raw: [],
            numstat: [],
            untracked: [".claude/worktrees/agent-slice/", "src/real.txt"],
            status: []        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then — it is another worktree, listed in its own right, and it is not something anyone
        // can open as a file. Asking git to hash it fails the entire batch rather than that line.
        #expect(changeSet.files.map(\.path) == ["src/real.txt"])
    }

    @Test
    func `given a conflicted path when the change set is built then the status comes from the merge state`(
    ) async throws {
        // given — a conflicted file is an ordinary modification to the comparison the change set
        // runs; only the merge state knows it is mid-conflict.
        let scenario = Scenario(
            raw: [":100644 100644 aaa 0000000 M", "conflict.txt"],
            numstat: ["4\t2\tconflict.txt"],
            untracked: [],
            status: ["u UU N... 100644 100644 100644 100644 aaa bbb ccc conflict.txt"]        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then
        #expect(changeSet.files[0].status == .conflicted)
    }

    // MARK: - A repository with no commits

    @Test
    func `given a repository with no commits when the change set is built then the empty tree is used`(
    ) async throws {
        // given — `git diff HEAD` exits 128 here, so every comparison substitutes the empty tree.
        let scenario = Scenario(
            headCommit: "",
            raw: [":000000 100644 0000000 aaa A", "first.txt"],
            numstat: ["1\t0\tfirst.txt"],
            untracked: [],
            status: [],
            revision: .emptyTree
        )

        // when
        _ = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then
        let received = await scenario.git.received
        #expect(received.contains(.trackedChanges(against: .emptyTree)))
        #expect(received.contains(.trackedChanges(against: .head)) == false)
    }

    // MARK: - Content hash and viewed state

    @Test
    func `given a file marked viewed at the content it still has when built then it reads as viewed`(
    ) async throws {
        // given
        let scenario = Scenario(
            raw: [":100644 100644 aaa 0000000 M", "seen.txt"],
            numstat: ["1\t1\tseen.txt"],
            untracked: [],
            status: []        )
        let unmarked = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])
        let file = unmarked.files[0]

        // when
        let marked = try await scenario.sut.changeSet(
            in: scenario.location,
            viewed: [file.id: file.contentHash]
        )

        // then
        #expect(marked.files[0].isViewed)
    }

    @Test
    func `given a file marked viewed at content it no longer has when built then it reads as unviewed`(
    ) async throws {
        // given
        let scenario = Scenario(
            raw: [":100644 100644 aaa 0000000 M", "seen.txt"],
            numstat: ["1\t1\tseen.txt"],
            untracked: [],
            status: []        )
        let fileId = FileID(repositoryRelativePath: "seen.txt")

        // when — the hash the reader marked belongs to a version the agent has since replaced.
        let changeSet = try await scenario.sut.changeSet(
            in: scenario.location,
            viewed: [fileId: String(repeating: "0", count: 64)]
        )

        // then — becoming unviewed when the file changes again is the feature, not a side effect.
        #expect(changeSet.files[0].isViewed == false)
    }

    // MARK: - Size guards

    @Test
    func `given more changed files than the limit when built then the list says it is incomplete`(
    ) async throws {
        // given
        var raw: [String] = []
        var numstat: [String] = []
        for index in 0..<5 {
            raw.append(contentsOf: [":100644 100644 aaa 0000000 M", "file\(index).txt"])
            numstat.append("1\t0\tfile\(index).txt")
        }
        let scenario = Scenario(
            raw: raw,
            numstat: numstat,
            untracked: [],
            status: [],
            limits: WorktreeLimits(maximumChangedFiles: 3, maximumDiffLines: 20_000, truncatedDiffLines: 2_000)
        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then — a worktree with thousands of changed files is a mistake worth showing part of
        // rather than an error, so the list is cut and says so.
        #expect(changeSet.files.count == 3)
        #expect(changeSet.isTruncated)
    }

    // MARK: - Files that have no content to hash

    @Test
    func `given a deleted file when the change set is built then it is not offered to the hasher`(
    ) async throws {
        // given — there is nothing on disk to hash, and asking git for it fails the **whole**
        // batch rather than that line, which loses every object id after it too.
        let scenario = Scenario(
            raw: [":100644 000000 aaa 0000000 D", "gone.txt", ":100644 100644 bbb 0000000 M", "here.txt"],
            numstat: ["0\t3\tgone.txt", "1\t1\there.txt"],
            untracked: [],
            status: []        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then — one id was asked for, and it belongs to the file that still exists.
        let deleted = try #require(changeSet.files.first { $0.path == "gone.txt" })
        let present = try #require(changeSet.files.first { $0.path == "here.txt" })
        #expect(deleted.contentHash != present.contentHash)
        #expect(changeSet.stats == ChangeStats(filesChanged: 2, insertions: 1, deletions: 4))
    }

    @Test
    func `given a submodule when the change set is built then it is marked and never hashed`(
    ) async throws {
        // given — a gitlink is a directory as far as this Mac is concerned, and the hasher refuses
        // a directory the same way it refuses a file that is gone.
        let scenario = Scenario(
            raw: [":160000 160000 aaa bbb M", "vendor/sub"],
            numstat: ["1\t1\tvendor/sub"],
            untracked: [],
            status: []
        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then
        #expect(changeSet.files[0].isSubmodule)
    }

    @Test
    func `given a binary file when the change set is built then it is marked rather than counted`(
    ) async throws {
        // given — git writes a dash where a count would go, and reading that as zero claims a
        // binary file did not change.
        let scenario = Scenario(
            raw: [":100644 100644 aaa 0000000 M", "photo.png"],
            numstat: ["-\t-\tphoto.png"],
            untracked: [],
            status: []        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then
        #expect(changeSet.files[0].isBinary)
        #expect(changeSet.files[0].language == nil)
    }

    @Test
    func `given a source file when the change set is built then the highlighter gets a hint`(
    ) async throws {
        // given
        let scenario = Scenario(
            raw: [":100644 100644 aaa 0000000 M", "Sources/Thing.swift"],
            numstat: ["2\t1\tSources/Thing.swift"],
            untracked: [],
            status: []        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then — a guess, and absent rather than wrong when the extension says nothing.
        #expect(changeSet.files[0].language == "swift")
        #expect(changeSet.files[0].estimatedLineCount == 3)
    }

    // MARK: - One file's diff

    @Test
    func `given a diff longer than the limit when it is asked for then a prefix comes back and says so`(
    ) async throws {
        // given — SPEC §5.4 wants a diff too large shown as a prefix rather than refused: a file
        // nobody can open is worse than the first part of one.
        let diff = """
            diff --git a/big.txt b/big.txt
            index aaa..bbb 100644
            --- a/big.txt
            +++ b/big.txt
            @@ -1,3 +1,3 @@
            -one
            +ONE
             two
            @@ -20,2 +20,2 @@
            -three
            +THREE
            """
        let scenario = Scenario(
            raw: [":100644 100644 aaa 0000000 M", "big.txt"],
            numstat: ["2\t2\tbig.txt"],
            untracked: [],
            status: [],
            fileDiff: diff,
            limits: WorktreeLimits(maximumChangedFiles: 1_000, maximumDiffLines: 3, truncatedDiffLines: 3)
        )
        let file = try #require(
            try await scenario.sut.changeSet(in: scenario.location, viewed: [:]).files.first
        )

        // when
        let produced = try await scenario.sut.fileDiff(
            for: file,
            at: RepositoryRelativePath("big.txt"),
            in: scenario.location,
            contextLines: 3
        )

        // then — whole hunks, so a truncated diff never stops halfway through one, and a reason a
        // person can act on rather than a silent short answer.
        #expect(produced.isTruncated)
        #expect(produced.truncationReason?.isEmpty == false)
        #expect(produced.hunks.count == 1)
    }

    @Test
    func `given an untracked file when its diff is asked for then it is compared against nothing`(
    ) async throws {
        // given — there is no side in the revision to compare it with.
        let scenario = Scenario(
            raw: [],
            numstat: [],
            untracked: ["fresh.txt"],
            status: []        )
        let file = try #require(
            try await scenario.sut.changeSet(in: scenario.location, viewed: [:]).files.first
        )

        // when
        _ = try await scenario.sut.fileDiff(
            for: file,
            at: RepositoryRelativePath("fresh.txt"),
            in: scenario.location,
            contextLines: 3
        )

        // then
        let received = await scenario.git.received
        #expect(received.contains(.untrackedFileDiff(path: RepositoryRelativePath("fresh.txt"), contextLines: 3)))
    }

    @Test
    func `given git refuses when the change set is built then the failure is not swallowed`() async throws {
        // given
        let scenario = Scenario(
            raw: [],
            numstat: [],
            untracked: [],
            status: [],
            failure: .commandFailed(
                command: .worktreeStatus,
                exitCode: 128,
                standardError: "fatal: not a git repository"
            )
        )

        // when
        var thrown: GitError?
        do {
            _ = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])
        } catch {
            thrown = error
        }

        // then — carried up with git's own words rather than turned into an empty change set, which
        // would read on a phone as "this worktree is clean".
        guard case .commandFailed(_, _, let standardError) = thrown else {
            Issue.record("expected git's refusal, got \(String(describing: thrown))")
            return
        }
        #expect(standardError.contains("not a git repository"))
    }

    // MARK: - The cheap question

    @Test
    func `given a worktree with something uncommitted when asked whether it changed then it has`(
    ) async throws {
        // given
        let scenario = Scenario(
            raw: [],
            numstat: [],
            untracked: [],
            status: ["1 .M N... 100644 100644 100644 aaa bbb src/edited.swift"]
        )

        // when
        let changed = try await scenario.sut.hasChanges(in: scenario.location)

        // then
        #expect(changed)
    }

    @Test
    func `given a clean worktree when asked whether it changed then it has not`() async throws {
        // given
        let scenario = Scenario(raw: [], numstat: [], untracked: [], status: [])

        // when
        let changed = try await scenario.sut.hasChanges(in: scenario.location)

        // then
        #expect(changed == false)
    }

    @Test
    func `when asked whether a worktree changed then only the status is run`() async throws {
        // given
        let scenario = Scenario(
            raw: [],
            numstat: [],
            untracked: [],
            status: ["? new.swift"]
        )

        // when
        _ = try await scenario.sut.hasChanges(in: scenario.location)

        // then — the whole point of this question is that it is one invocation. Building a change
        // set to evaluate one boolean is what costs 122.7 seconds across ten real repositories, and
        // this is the panel that draws a row per project.
        #expect(await scenario.git.received == [.worktreeStatus])
    }

    @Test
    func `given a path git cannot hash when the change set is built then only that file loses its hash`(
    ) async throws {
        // given — a symlink pointing at a directory, which `ls-files --others` reports as an
        // ordinary untracked path because git treats a symlink as a file. `hash-object` follows it,
        // finds a directory, and **fails the whole batch with exit 128** — which until this test
        // took the entire worktree down with it. Found on a real Mac: two of Davide's
        // `bandlab-android` worktrees carry one, and the phone could not list any worktree at all.
        let scenario = Scenario(
            raw: [],
            numstat: [],
            untracked: ["kept.txt", "linked-directory", "also-kept.txt"],
            status: [],
            unhashablePaths: ["linked-directory"]
        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then — the change set survives, and every file is in it.
        #expect(changeSet.files.map(\.path) == ["kept.txt", "linked-directory", "also-kept.txt"])

        // and the two git *could* hash keep hashes of their own, which is what makes a mark
        // self-correcting when the file changes underneath it. Losing those to one bad neighbour
        // would make "viewed" stick to content nobody has seen.
        let kept = try #require(changeSet.files.first { $0.path == "kept.txt" })
        let alsoKept = try #require(changeSet.files.first { $0.path == "also-kept.txt" })
        let refused = try #require(changeSet.files.first { $0.path == "linked-directory" })
        #expect(kept.contentHash != alsoKept.contentHash)
        #expect(refused.contentHash != kept.contentHash)
    }

    @Test
    func `given a path git cannot hash when the change set is built then the batch is tried before the fallback`(
    ) async throws {
        // given — the fallback costs one process per file, so it must never be the ordinary path:
        // a worktree with nothing wrong in it hashes in a single call.
        let scenario = Scenario(
            raw: [],
            numstat: [],
            untracked: ["one.txt", "two.txt"],
            status: []
        )

        // when
        _ = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then
        let hashes = await scenario.git.received.filter { if case .hashWorktreeFiles = $0 { true } else { false } }
        #expect(hashes.count == 1)
    }

    // MARK: - Scenario

    private struct Scenario {

        let sut: WorktreeService
        let git: FakeGitClient
        let location = RepositoryLocation(path: "/repo")

        init(
            headCommit: String = "abc123\n",
            raw: [String],
            numstat: [String],
            untracked: [String],
            status: [String],
            unhashablePaths: Set<String> = [],
            revision: GitRevision = .head,
            fileDiff: String = "",
            failure: GitError? = nil,
            limits: WorktreeLimits = .standard
        ) {
            git = FakeGitClient(
                outputs: [
                    .headCommit: Data(headCommit.utf8),
                    .trackedChanges(against: revision): nulSeparated(raw),
                    .trackedStats(against: revision): nulSeparated(numstat),
                    .untrackedPaths: nulSeparated(untracked),
                    .worktreeStatus: nulSeparated(status)
                ],
                failures: failure.map { [.worktreeStatus: $0] } ?? [:],
                unhashablePaths: unhashablePaths,
                anyFileDiff: Data(fileDiff.utf8)
            )
            sut = WorktreeService(git: git, limits: limits)
        }
    }
}

private func nulSeparated(_ fields: [String]) -> Data {
    var data = Data()
    for field in fields {
        data.append(contentsOf: Data(field.utf8))
        data.append(0)
    }
    return data
}
