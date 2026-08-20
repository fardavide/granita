import Foundation
import Testing

@testable import CoreDiffDomain

/// The highest risk component in the product: every assertion here is against output the real `git`
/// binary produced, because the cases that break a diff parser are the ones nobody writes by hand.
@Suite("Unified diff parser")
struct UnifiedDiffParserTests {

    // MARK: - Files

    @Test
    func `given a clean path when parsed then there are no files at all`() throws {
        // given — a zero-byte diff, which is what a path with no changes produces.
        let text = try Fixture.text("case-empty.diff")

        // when
        let files = UnifiedDiffParser.parse(text)

        // then — not one file with no hunks.
        #expect(files.isEmpty)
    }

    @Test
    func `given several files in one diff when parsed then each becomes its own file`() throws {
        // given
        let text = try Fixture.text("case-no-newline.diff")

        // when
        let files = UnifiedDiffParser.parse(text)

        // then
        #expect(files.map(\.path) == [
            "src/no-newline-both.txt", "src/no-newline-gained.txt", "src/no-newline-lost.txt"
        ])
    }

    @Test
    func `given the whole working tree when parsed then every file appears exactly once`() throws {
        // given
        let text = try Fixture.text("working-tree.diff")

        // when
        let files = UnifiedDiffParser.parse(text)

        // then
        #expect(files.map(\.path) == [
            "src/a file with spaces.txt",
            "src/added.txt",
            "src/binary.bin",
            "src/caffè-日本語-🧊.txt",
            "src/crlf.txt",
            "src/deleted.txt",
            "src/mode-change.sh",
            "src/modified.txt",
            "src/no-newline-both.txt",
            "src/no-newline-gained.txt",
            "src/no-newline-lost.txt",
            "src/renamed-to.txt",
            "src/sectioned.swift",
            "src/single-line.txt",
            "vendor/sub"
        ])
    }

    // MARK: - Paths

    @Test
    func `given a path containing spaces when parsed then the tab git appends is not part of it`() throws {
        // given — git terminates the ---/+++ path with a TAB when the path contains a space.
        let text = try Fixture.text("case-path-with-spaces.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then
        #expect(file.path == "src/a file with spaces.txt")
    }

    @Test
    func `given a non-ascii path when parsed then it survives unchanged`() throws {
        // given
        let text = try Fixture.text("case-path-non-ascii.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then
        #expect(file.path == "src/caffè-日本語-🧊.txt")
    }

    @Test
    func `given a rename when parsed then the old path is kept and is not swapped with the new one`() throws {
        // given
        let text = try Fixture.text("case-renamed.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then
        #expect(file.path == "src/renamed-to.txt")
        #expect(file.oldPath == "src/renamed-from.txt")
    }

    @Test
    func `given a file that was not renamed when parsed then it has no old path`() throws {
        // given
        let text = try Fixture.text("case-modified.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then — an old path that merely repeats the current one would make every consumer check.
        #expect(file.oldPath == nil)
    }

    @Test
    func `given a new file when parsed then the dev null side is not read as its path`() throws {
        // given
        let text = try Fixture.text("case-added.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then
        #expect(file.path == "src/added.txt")
        #expect(file.oldPath == nil)
    }

    @Test
    func `given a deleted file when parsed then the path it had is the one reported`() throws {
        // given
        let text = try Fixture.text("case-deleted.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then
        #expect(file.path == "src/deleted.txt")
    }

    // MARK: - Hunks

    @Test
    func `given a file with two hunks when parsed then each carries its own range and index`() throws {
        // given
        let text = try Fixture.text("case-modified.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then
        #expect(file.hunks.map(\.index) == [0, 1])
        #expect(file.hunks.map(\.oldStart) == [1, 7])
        #expect(file.hunks.map(\.oldCount) == [4, 4])
        #expect(file.hunks.map(\.newStart) == [1, 7])
        #expect(file.hunks.map(\.newCount) == [4, 4])
    }

    @Test
    func `given a hunk header that omits its counts when parsed then both default to one`() throws {
        // given — `@@ -1 +1 @@`, which git emits for a single-line file.
        let text = try Fixture.text("case-omitted-hunk-counts.diff")

        // when
        let hunk = try #require(UnifiedDiffParser.parse(text).first?.hunks.first)

        // then
        #expect(hunk.oldCount == 1)
        #expect(hunk.newCount == 1)
    }

    @Test
    func `given a section heading after the closing at signs when parsed then it is kept`() throws {
        // given
        let text = try Fixture.text("case-section-heading.diff")

        // when
        let hunk = try #require(UnifiedDiffParser.parse(text).first?.hunks.first)

        // then
        #expect(hunk.sectionHeading == "import Foundation")
    }

    @Test
    func `given a hunk with no section heading when parsed then it has none`() throws {
        // given
        let text = try Fixture.text("case-modified.diff")

        // when
        let hunks = try #require(UnifiedDiffParser.parse(text).first?.hunks)

        // then — the second hunk of this file does carry one, so an empty string would hide the
        // difference between the two.
        #expect(hunks.first?.sectionHeading == nil)
        #expect(hunks.last?.sectionHeading == "six")
    }

    // MARK: - Lines

    @Test
    func `given a modified hunk when parsed then each line kind is numbered on the sides it exists on`() throws {
        // given
        let text = try Fixture.text("case-modified.diff")

        // when
        let hunk = try #require(UnifiedDiffParser.parse(text).first?.hunks.first)

        // then
        #expect(hunk.lines.map(\.kind) == [.deletion, .addition, .context, .context, .context])
        #expect(hunk.lines.map(\.text) == ["one", "ONE", "two", "three", "four"])
        #expect(hunk.lines.map(\.oldNumber) == [1, nil, 2, 3, 4])
        #expect(hunk.lines.map(\.newNumber) == [nil, 1, 2, 3, 4])
    }

    @Test
    func `given a hunk starting away from the top of the file when parsed then numbering starts there`() throws {
        // given — `@@ -2,7 +2,7 @@`.
        let text = try Fixture.text("case-renamed.diff")

        // when
        let hunk = try #require(UnifiedDiffParser.parse(text).first?.hunks.first)

        // then
        #expect(hunk.lines.first?.oldNumber == 2)
        #expect(hunk.lines.first?.newNumber == 2)
        #expect(hunk.lines.last?.oldNumber == 8)
    }

    @Test
    func `given an added file when parsed then nothing carries an old line number`() throws {
        // given
        let text = try Fixture.text("case-added.diff")

        // when
        let hunk = try #require(UnifiedDiffParser.parse(text).first?.hunks.first)

        // then
        #expect(hunk.lines.map(\.kind) == [.addition, .addition])
        #expect(hunk.lines.allSatisfy { $0.oldNumber == nil })
        #expect(hunk.lines.map(\.newNumber) == [1, 2])
    }

    @Test
    func `given a deleted file when parsed then nothing carries a new line number`() throws {
        // given
        let text = try Fixture.text("case-deleted.diff")

        // when
        let hunk = try #require(UnifiedDiffParser.parse(text).first?.hunks.first)

        // then
        #expect(hunk.lines.map(\.kind) == [.deletion, .deletion])
        #expect(hunk.lines.map(\.oldNumber) == [1, 2])
        #expect(hunk.lines.allSatisfy { $0.newNumber == nil })
    }

    @Test
    func `given the prefix character when parsed then it is not part of the line text`() throws {
        // given — an indented line, so a parser dropping one character too many shows up.
        let text = try Fixture.text("case-section-heading.diff")

        // when
        let lines = try #require(UnifiedDiffParser.parse(text).first?.hunks.first?.lines)

        // then
        #expect(lines.contains { $0.kind == .addition && $0.text == "    let c = 30" })
        #expect(lines.contains { $0.kind == .deletion && $0.text == "    let c = 3" })
    }

    @Test
    func `given crlf content when parsed then the carriage return stays in the text`() throws {
        // given
        let text = try Fixture.text("case-crlf.diff")

        // when
        let lines = try #require(UnifiedDiffParser.parse(text).first?.hunks.first?.lines)

        // then — the CR is content: it is what makes the file a CRLF file, and the viewer shows it.
        #expect(lines.map(\.text) == ["first\r", "second\r", "SECOND\r", "third\r"])
    }

    @Test
    func `given a no newline marker when parsed then it is a line of its own that numbers nothing`() throws {
        // given
        let text = try Fixture.text("case-no-newline.diff")

        // when
        let hunk = try #require(UnifiedDiffParser.parse(text).first?.hunks.first)

        // then — it is rendered, never counted as content, so it advances neither side.
        #expect(hunk.lines.map(\.kind) == [.deletion, .noNewlineMarker, .addition, .noNewlineMarker])
        #expect(hunk.lines.map(\.oldNumber) == [1, nil, nil, nil])
        #expect(hunk.lines.map(\.newNumber) == [nil, nil, 1, nil])
    }

    @Test
    func `given a no newline marker when parsed then its text is the message without the backslash`() throws {
        // given
        let text = try Fixture.text("case-no-newline.diff")

        // when
        let lines = try #require(UnifiedDiffParser.parse(text).first?.hunks.first?.lines)

        // then
        #expect(lines[1].text == "No newline at end of file")
    }

    @Test
    func `given lines when parsed then their display columns are measured`() throws {
        // given — tabs, wide characters, a combining mark and a 400 column line.
        let text = try Fixture.text("case-display-columns.diff")

        // when
        let lines = try #require(UnifiedDiffParser.parse(text).first?.hunks.first?.lines)

        // then
        #expect(lines.map(\.displayColumns) == [20, 21, 16, 22, 16, 400])
    }

    @Test
    func `given a line the client must measure itself when parsed then it says so`() throws {
        // given
        let text = try Fixture.text("case-path-non-ascii.diff")

        // when
        let lines = try #require(UnifiedDiffParser.parse(text).first?.hunks.first?.lines)

        // then — only the line carrying the emoji, not the whole file.
        #expect(lines.map(\.needsMeasurement) == [false, true])
    }

    // MARK: - Conflicts

    @Test
    func `given a conflicted file when parsed then the three markers are tagged as markers`() throws {
        // given — a conflicted path diffs as an ordinary unified diff carrying the markers inline,
        // not as a combined diff.
        let text = try Fixture.text("case-conflicted.diff")

        // when
        let lines = try #require(UnifiedDiffParser.parse(text).first?.hunks.first?.lines)

        // then
        #expect(lines.map(\.kind) == [
            .context, .conflictMarker, .context, .conflictMarker, .addition, .conflictMarker, .context
        ])
    }

    @Test
    func `given a conflict marker when parsed then it is numbered like the line it replaced`() throws {
        // given
        let text = try Fixture.text("case-conflicted.diff")

        // when
        let lines = try #require(UnifiedDiffParser.parse(text).first?.hunks.first?.lines)

        // then — the markers are real lines of the working copy, so the new side counts them.
        #expect(lines.map(\.newNumber) == [1, 2, 3, 4, 5, 6, 7])
        #expect(lines.map(\.oldNumber) == [1, nil, 2, nil, nil, nil, 3])
    }

    @Test
    func `given a row of equals signs outside a conflict when parsed then it stays ordinary content`() throws {
        // given — a Markdown heading underline, which is the false positive a bare prefix match
        // would produce on any documentation file.
        let text = """
            diff --git a/doc.md b/doc.md
            index 1111111..2222222 100644
            --- a/doc.md
            +++ b/doc.md
            @@ -1,2 +1,2 @@
             Title
            -=======
            +=========

            """

        // when
        let lines = try #require(UnifiedDiffParser.parse(text).first?.hunks.first?.lines)

        // then
        #expect(lines.map(\.kind) == [.context, .deletion, .addition])
    }

    // MARK: - Files with no hunks

    @Test
    func `given a mode change and nothing else when parsed then the file is present with no hunks`() throws {
        // given
        let text = try Fixture.text("case-mode-change-only.diff")

        // when
        let files = UnifiedDiffParser.parse(text)

        // then — the path has no ---/+++ lines at all, so it exists only in the `diff --git` header.
        #expect(files.map(\.path) == ["src/mode-change.sh"])
        #expect(files.first?.hunks.isEmpty == true)
    }

    @Test
    func `given a binary summary when parsed then the file is binary and carries no hunks`() throws {
        // given
        let text = try Fixture.text("binary-differs.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then
        #expect(file.isBinary)
        #expect(file.hunks.isEmpty)
    }

    @Test
    func `given a binary patch when parsed then its payload is not read as diff lines`() throws {
        // given — `--binary` emits a base85 payload whose lines start with letters and digits, and
        // whose blank line separates the two literals.
        let text = try Fixture.text("binary-patch.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then
        #expect(file.isBinary)
        #expect(file.hunks.isEmpty)
    }

    @Test
    func `given a submodule when parsed then it is flagged as one`() throws {
        // given — the 160000 mode on the index line is the only thing that says so.
        let text = try Fixture.text("case-submodule.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then
        #expect(file.isSubmodule)
        #expect(file.isBinary == false)
    }

    @Test
    func `given an ordinary file when parsed then it is neither binary nor a submodule`() throws {
        // given
        let text = try Fixture.text("case-modified.diff")

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then
        #expect(file.isBinary == false)
        #expect(file.isSubmodule == false)
    }

    // MARK: - Malformed input

    @Test
    func `given a diff cut off inside a hunk when parsed then the lines before the cut survive`() throws {
        // given — not a fixture, because git cannot produce one: the size guard truncates a large
        // diff to its first lines, so the parser is handed a hunk that stops mid-way.
        let text = """
            diff --git a/src/modified.txt b/src/modified.txt
            index c9e9e05..d96039a 100644
            --- a/src/modified.txt
            +++ b/src/modified.txt
            @@ -1,4 +1,4 @@
            -one
            +ONE
            """

        // when
        let file = try #require(UnifiedDiffParser.parse(text).first)

        // then — the declared counts stay as git wrote them; only the lines are short.
        #expect(file.hunks.first?.newCount == 4)
        #expect(file.hunks.first?.lines.map(\.text) == ["one", "ONE"])
    }

    @Test
    func `given text that is not a diff at all when parsed then nothing is invented`() {
        // given
        let text = "fatal: ambiguous argument 'HEAD'\n"

        // when
        let files = UnifiedDiffParser.parse(text)

        // then
        #expect(files.isEmpty)
    }
}
