import Foundation
import Testing

import CoreDiffDomain
import ServerGitDomain
@testable import ServerWorktreesDomain

@Suite("Worktree context")
struct WorktreeContextTests {

    @Test
    func `given unchanged lines after the last change when reading a diff then its line counts include the remainder`() async throws {
        // given
        let original = (1...1_000).map { "line \($0)" }
        let working = original.enumerated().map { index, line in
            index == 199 || index == 599 ? "changed \(index + 1)" : line
        }
        let scenario = Scenario(
            original: original,
            working: working,
            diff: """
                diff --git a/long.txt b/long.txt
                index aaa..bbb 100644
                --- a/long.txt
                +++ b/long.txt
                @@ -197,7 +197,7 @@
                 line 197
                 line 198
                 line 199
                -line 200
                +changed 200
                 line 201
                 line 202
                 line 203
                @@ -597,7 +597,7 @@
                 line 597
                 line 598
                 line 599
                -line 600
                +changed 600
                 line 601
                 line 602
                 line 603
                """
        )

        // when
        let diff = try await scenario.sut.fileDiff(
            for: scenario.file,
            at: scenario.path,
            in: scenario.location,
            contextLines: 3
        )

        // then
        #expect(diff.oldLineCount == 1_000)
        #expect(diff.newLineCount == 1_000)
    }

    @Test
    func `given context exceeds its limit when reading a complete diff then changes remain without advertising unreachable context`() async throws {
        // given
        let original = (1...1_000).map { "line \($0)" }
        let scenario = Scenario(
            original: original,
            working: original.enumerated().map { index, line in
                index == 599 ? "changed 600" : line
            },
            diff: """
                diff --git a/long.txt b/long.txt
                index aaa..bbb 100644
                --- a/long.txt
                +++ b/long.txt
                @@ -597,7 +597,7 @@
                 line 597
                 line 598
                 line 599
                -line 600
                +changed 600
                 line 601
                 line 602
                 line 603
                """,
            contextLineLimit: 10
        )

        // when
        let diff = try await scenario.sut.fileDiff(
            for: scenario.file,
            at: scenario.path,
            in: scenario.location,
            contextLines: 3
        )

        // then
        #expect(diff.hunks.count == 1)
        #expect(diff.hunks.first?.lines.map(\.text) == [
            "line 597", "line 598", "line 599", "line 600", "changed 600",
            "line 601", "line 602", "line 603"
        ])
        #expect(diff.oldLineCount == 603)
        #expect(diff.newLineCount == 603)
        #expect(diff.isTruncated)
        #expect(diff.truncationReason?.isEmpty == false)
    }

    private struct Scenario {

        let sut: WorktreeService
        let file: FileChange
        let path = RepositoryRelativePath("long.txt")
        let location = RepositoryLocation(path: "/repo")

        init(original: [String], working: [String], diff: String, contextLineLimit: Int = .max) {
            let fullAddition = """
                diff --git a/long.txt b/long.txt
                new file mode 100644
                --- /dev/null
                +++ b/long.txt
                @@ -0,0 +1,\(working.count) @@
                """ + "\n" + working.prefix(contextLineLimit).map { "+" + $0 }.joined(separator: "\n") + "\n"
            sut = WorktreeService(
                git: FakeGitClient(
                    outputs: [
                        .headCommit: Data("abc123\n".utf8),
                        .fileDiff(path: path, against: .head, contextLines: 3): Data(diff.utf8),
                        .fileContent(path: path, at: .head): Data((original.joined(separator: "\n") + "\n").utf8),
                        .untrackedFileDiff(path: path, contextLines: 0): Data(fullAddition.utf8)
                    ],
                    failures: [:],
                    truncated: working.count > contextLineLimit
                        ? [.untrackedFileDiff(path: path, contextLines: 0)] : []
                ),
                files: FakeWorktreeFileReading(),
                limits: .standard
            )
            file = FileChange(
                id: FileID(repositoryRelativePath: "long.txt"),
                path: "long.txt",
                oldPath: nil,
                status: .modified,
                isBinary: false,
                isSubmodule: false,
                stats: ChangeStats(filesChanged: 1, insertions: 2, deletions: 2),
                contentHash: "long-file-content",
                estimatedLineCount: 4,
                isViewed: false,
                isTruncated: false,
                language: nil
            )
        }
    }
}
