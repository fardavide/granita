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
            status: [],
            worktreeObjectIds: ["0102a25aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"]
        )

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
            status: [],
            worktreeObjectIds: ["1111111111111111111111111111111111111111", "2222222222222222222222222222222222222222"]
        )

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
            status: [],
            worktreeObjectIds: ["8888888888888888888888888888888888888888"]
        )

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
            status: ["u UU N... 100644 100644 100644 100644 aaa bbb ccc conflict.txt"],
            worktreeObjectIds: ["3333333333333333333333333333333333333333"]
        )

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
            worktreeObjectIds: ["4444444444444444444444444444444444444444"],
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
            status: [],
            worktreeObjectIds: ["5555555555555555555555555555555555555555"]
        )
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
            status: [],
            worktreeObjectIds: ["6666666666666666666666666666666666666666"]
        )
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
            worktreeObjectIds: Array(repeating: String(repeating: "7", count: 40), count: 5),
            limits: WorktreeLimits(maximumChangedFiles: 3, maximumDiffLines: 20_000, truncatedDiffLines: 2_000)
        )

        // when
        let changeSet = try await scenario.sut.changeSet(in: scenario.location, viewed: [:])

        // then — a worktree with thousands of changed files is a mistake worth showing part of
        // rather than an error, so the list is cut and says so.
        #expect(changeSet.files.count == 3)
        #expect(changeSet.isTruncated)
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
            worktreeObjectIds: [String],
            revision: GitRevision = .head,
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
                failures: [:],
                hashedObjectIds: worktreeObjectIds
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
