import Foundation
import Testing

import CoreDiffDomain
import ServerGitDomain
@testable import ServerWorktreesDomain

@Suite("Worktree context")
struct WorktreeContextTests {

    @Test
    func `given insertion and deletion hunks when preparing highlighting then neither shifts the hidden lines`() async throws {
        // given
        let original = ["start", "keep", "remove", "tail"]
        let working = ["start", "insert", "keep", "tail"]
        let scenario = Scenario(original: original, working: working, diff: """
            diff --git a/long.txt b/long.txt
            index aaaaaaa..bbbbbbb 100644
            --- a/long.txt
            +++ b/long.txt
            @@ -1,0 +2 @@
            +insert
            @@ -3 +3,0 @@
            -remove
            """, language: "kotlin", workingEndsWithNewline: false)

        // when
        let diff = try await scenario.sut.fileDiff(
            for: scenario.file, at: scenario.path, in: scenario.location, contextLines: 3
        )

        // then
        #expect(diff.oldHighlightingSource == original.joined(separator: "\n"))
        #expect(diff.newHighlightingSource == working.joined(separator: "\n"))
    }

    enum InconsistentPatch: CaseIterable {
        case missingBlobSeparator, emptyBlob, incompleteWorkingCopy, mismatchedHunkOffsets, mismatchedHunkText, removedConflictMarker
    }

    @Test(arguments: InconsistentPatch.allCases)
    func `given the patch cannot be reversed safely when reading a diff then no hidden source is sent`(
        reason: InconsistentPatch
    ) async throws {
        // given
        let index = switch reason {
        case .missingBlobSeparator: "aaaaaaabbbbbbb"
        case .emptyBlob: "aaaaaaa.."
        case .incompleteWorkingCopy, .mismatchedHunkOffsets, .mismatchedHunkText, .removedConflictMarker: "aaaaaaa..bbbbbbb"
        }
        let changedLine = reason == .mismatchedHunkText ? "unexpected" : "after"
        let oldLine = reason == .removedConflictMarker ? "<<<<<<< HEAD" : "before"
        let oldStart = reason == .mismatchedHunkOffsets ? 1 : 2
        let scenario = Scenario(original: ["hidden", oldLine], working: ["hidden", "after"], diff: """
            diff --git a/long.txt b/long.txt
            index \(index) 100644
            --- a/long.txt
            +++ b/long.txt
            @@ -\(oldStart) +2 @@
            -\(oldLine)
            +\(changedLine)
            """, language: "kotlin", workingDeclaredLineCount: reason == .incompleteWorkingCopy ? 3 : nil)

        // when
        let diff = try await scenario.sut.fileDiff(
            for: scenario.file, at: scenario.path, in: scenario.location, contextLines: 3
        )

        // then
        #expect(diff.hunks.count == 1)
        #expect(diff.oldHighlightingSource == nil)
        #expect(diff.newHighlightingSource == nil)
    }

    @Test
    func `given hidden text exceeds the byte limit when reading a diff then the visible changes remain`() async throws {
        // given
        let hidden = String(repeating: "a", count: DiffHighlightingLimits.bytes)
        let scenario = Scenario(original: [hidden, "before"], working: [hidden, "after"], diff: """
            diff --git a/long.txt b/long.txt
            index aaaaaaa..bbbbbbb 100644
            --- a/long.txt
            +++ b/long.txt
            @@ -2 +2 @@
            -before
            +after
            """, language: "kotlin")

        // when
        let diff = try await scenario.sut.fileDiff(
            for: scenario.file, at: scenario.path, in: scenario.location, contextLines: 3
        )

        // then
        #expect(diff.hunks.flatMap(\.lines).map(\.text) == ["before", "after"])
        #expect(diff.oldHighlightingSource == nil)
        #expect(diff.newHighlightingSource == nil)
    }

    @Test
    func `given a closing comment between hunks when reading the diff then the payload carries both complete sources`() async throws {
        // given
        let scenario = Scenario(
            original: ["/**", " */", "fun oldName() = 1"],
            working: ["/**", " */", "fun newName() = 1"],
            diff: """
                diff --git a/long.txt b/long.txt
                index aaaaaaa..bbbbbbb 100644
                --- a/long.txt
                +++ b/long.txt
                @@ -1 +1 @@
                 /**
                @@ -3 +3 @@
                -fun oldName() = 1
                +fun newName() = 1
                """,
            language: "kotlin"
        )

        // when
        let diff = try await scenario.sut.fileDiff(for: scenario.file, at: scenario.path, in: scenario.location, contextLines: 3)
        let payload = try JSONDecoder().decode(HighlightingPayload.self, from: JSONEncoder().encode(diff))

        // then
        #expect(payload.oldHighlightingSource == "/**\n */\nfun oldName() = 1")
        #expect(payload.newHighlightingSource == "/**\n */\nfun newName() = 1")
        #expect(diff.hunks.flatMap(\.lines).allSatisfy { $0.text != " */" })
    }

    @Test
    func `given the new side exceeds the highlighting limit when reading the diff then the old side keeps its context`() async throws {
        // given
        let original = Array(repeating: "// Kotlin", count: DiffHighlightingLimits.lines)
        let scenario = Scenario(
            original: original,
            working: original + ["fun added() = 1"],
            diff: """
                diff --git a/long.txt b/long.txt
                index aaaaaaa..bbbbbbb 100644
                --- a/long.txt
                +++ b/long.txt
                @@ -4000 +4000,2 @@
                 // Kotlin
                +fun added() = 1
                """,
            language: "kotlin"
        )

        // when
        let diff = try await scenario.sut.fileDiff(for: scenario.file, at: scenario.path, in: scenario.location, contextLines: 3)

        // then
        #expect(diff.oldHighlightingSource == original.joined(separator: "\n"))
        #expect(diff.newHighlightingSource == nil)
    }

    @Test
    func `given literal conflict markers when sending a modified diff then they stay out of the highlighting source`() async throws {
        // given
        let scenario = Scenario(
            original: ["// Kotlin", "<<<<<<< HEAD", "fun oldName() = 1"],
            working: ["// Kotlin", "<<<<<<< HEAD", "fun newName() = 1"],
            diff: """
                diff --git a/long.txt b/long.txt
                index aaaaaaa..bbbbbbb 100644
                --- a/long.txt
                +++ b/long.txt
                @@ -3 +3 @@
                -fun oldName() = 1
                +fun newName() = 1
                """,
            language: "kotlin"
        )

        // when
        let diff = try await scenario.sut.fileDiff(for: scenario.file, at: scenario.path, in: scenario.location, contextLines: 3)

        // then
        #expect(diff.oldHighlightingSource == nil)
        #expect(diff.newHighlightingSource == nil)
    }

    @Test
    func `given the working blob changed between reads when sending the diff then hidden source is omitted`() async throws {
        // given
        let scenario = Scenario(
            original: ["/**", " */", "fun oldName() = 1"],
            working: ["/**", " * Still open", "fun newName() = 1"],
            diff: """
                diff --git a/long.txt b/long.txt
                index aaaaaaa..ccccccc 100644
                --- a/long.txt
                +++ b/long.txt
                @@ -3 +3 @@
                -fun oldName() = 1
                +fun newName() = 1
                """,
            language: "kotlin"
        )

        // when
        let diff = try await scenario.sut.fileDiff(for: scenario.file, at: scenario.path, in: scenario.location, contextLines: 3)

        // then
        #expect(diff.oldHighlightingSource == nil)
        #expect(diff.newHighlightingSource == nil)
    }

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

        init(
            original: [String], working: [String], diff: String, contextLineLimit: Int = .max,
            language: String? = nil, workingEndsWithNewline: Bool = true, workingDeclaredLineCount: Int? = nil
        ) {
            let terminator = workingEndsWithNewline ? "\n" : "\n\\ No newline at end of file\n"
            let fullAddition = """
                diff --git a/long.txt b/long.txt
                new file mode 100644
                index 0000000..bbbbbbb
                --- /dev/null
                +++ b/long.txt
                @@ -0,0 +1,\(workingDeclaredLineCount ?? working.count) @@
                """ + "\n" + working.prefix(contextLineLimit).map { "+" + $0 }.joined(separator: "\n") + terminator
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
                language: language
            )
        }
    }

    private struct HighlightingPayload: Decodable {
        let oldHighlightingSource: String?
        let newHighlightingSource: String?
    }
}
