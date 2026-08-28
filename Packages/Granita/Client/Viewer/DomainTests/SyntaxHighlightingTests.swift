import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// What the highlighter is given, and what it is refused.
///
/// **`SPEC.md` §10 fixes the shape and the reason for it**: per file per side, never per hunk,
/// because a hunk starting inside a class body, a multi-line string or a heredoc gives the lexer no
/// opening context and mis-lexes the whole block. So one side of a file becomes one string, is
/// lexed once, and is split back by newline and indexed into the hunks.
///
/// **Which side a line is on is the parser's own answer, not a second one.** `UnifiedDiffParser`
/// already decides that a context line occupies both sides, a deletion only the old and an addition
/// only the new — and that a conflict marker and a no-newline annotation occupy neither. Reading
/// that off the numbers it wrote is what stops this file inventing a second opinion about it, and it
/// is why `<<<<<<<` never reaches the lexer.
@Suite("Syntax highlighting")
struct SyntaxHighlightingTests {

    // MARK: - Which lines make up a side

    @Test
    func `given a modified file when the new side is assembled then it is the context and the additions`() {
        // given
        let diff = aDiff(hunks: [aHunk()])

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .new)

        // then — the deletion is absent and everything else is in file order. The text is what the
        // lexer sees, so it is asserted whole rather than by line count.
        #expect(plan == .highlight(
            HighlightSource(
                side: .new,
                text: "final class Reader {\n    let store: Store\n}",
                lineNumbers: [10, 11, 12]
            )
        ))
    }

    @Test
    func `given a modified file when the old side is assembled then it is the context and the deletions`() {
        // given
        let diff = aDiff(hunks: [aHunk()])

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .old)

        // then — the addition is absent, and the old numbering is the one that survives.
        #expect(plan == .highlight(
            HighlightSource(
                side: .old,
                text: "final class Reader {\n    var store: Store?\n}",
                lineNumbers: [10, 11, 12]
            )
        ))
    }

    @Test
    func `given a conflicted file when a side is assembled then the markers reach the lexer on neither`() {
        // given — a conflict diffs as an ordinary unified diff carrying the markers inline, and the
        // parser gives them a number on neither side.
        let diff = aDiff(hunks: [
            Hunk(
                index: 0,
                oldStart: 10,
                oldCount: 1,
                newStart: 10,
                newCount: 3,
                sectionHeading: nil,
                lines: [
                    aLine(kind: .conflictMarker, old: nil, new: nil, text: "<<<<<<< HEAD"),
                    aLine(kind: .addition, old: nil, new: 10, text: "let store = Store()"),
                    aLine(kind: .conflictMarker, old: nil, new: nil, text: "======="),
                    aLine(kind: .context, old: 10, new: 11, text: "}"),
                    aLine(kind: .conflictMarker, old: nil, new: nil, text: ">>>>>>> theirs")
                ]
            )
        ])

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .new)

        // then — `<<<<<<<` is not Swift, and a lexer handed it mis-lexes everything after it. §4
        // already draws a marker in its own colour and semibold, so nothing is lost by keeping it
        // out of the string the highlighter reads.
        #expect(plan == .highlight(
            HighlightSource(side: .new, text: "let store = Store()\n}", lineNumbers: [10, 11])
        ))
    }

    @Test
    func `given a file with no trailing newline when a side is assembled then git's annotation is not one of its lines`() {
        // given — `\ No newline at end of file` is git talking about the file rather than a line of
        // it, and the parser gives it no number on either side.
        let diff = aDiff(hunks: [
            Hunk(
                index: 0,
                oldStart: 1,
                oldCount: 1,
                newStart: 1,
                newCount: 1,
                sectionHeading: nil,
                lines: [
                    aLine(kind: .addition, old: nil, new: 1, text: "let a = 1"),
                    aLine(kind: .noNewlineMarker, old: nil, new: nil, text: " No newline at end of file")
                ]
            )
        ])

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .new)

        // then
        #expect(plan == .highlight(HighlightSource(side: .new, text: "let a = 1", lineNumbers: [1])))
    }

    @Test
    func `given hunks with a gap between them when a side is assembled then the lines are joined and the numbers say so`() {
        // given — two hunks forty lines apart, which is the ordinary case and the one that makes
        // this an approximation rather than the file.
        let diff = aDiff(hunks: [
            Hunk(
                index: 0,
                oldStart: 10,
                oldCount: 1,
                newStart: 10,
                newCount: 1,
                sectionHeading: nil,
                lines: [aLine(kind: .context, old: 10, new: 10, text: "struct A {")]
            ),
            Hunk(
                index: 1,
                oldStart: 50,
                oldCount: 1,
                newStart: 50,
                newCount: 1,
                sectionHeading: nil,
                lines: [aLine(kind: .context, old: 50, new: 50, text: "struct B {")]
            )
        ])

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .new)

        // then — the two are adjacent in the string the lexer reads and forty apart in the file.
        // **The line numbers are the record of that**, and they are what the highlighted lines are
        // indexed back by, so nothing downstream has to know the string had a gap in it.
        #expect(plan == .highlight(
            HighlightSource(side: .new, text: "struct A {\nstruct B {", lineNumbers: [10, 50])
        ))
    }

    // MARK: - What is refused, and why

    @Test
    func `given a file claiming no language when a side is assembled then it is refused`() {
        // given
        let diff = aDiff(hunks: [aHunk()], language: nil)

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .new)

        // then — `SPEC.md` §10 in as many words: skip entirely when `language` is nil and render
        // plain monospaced text.
        #expect(plan == .refuse(.noLanguage))
    }

    @Test
    func `given a side longer than the limit when it is assembled then it is refused by line count`() {
        // given — one line over, so the boundary is asserted rather than the middle of the range.
        let lines = (1...(SyntaxHighlighting.lineLimit + 1)).map {
            aLine(kind: .context, old: $0, new: $0, text: "x")
        }
        let diff = aDiff(hunks: [aHunk(lines: lines)])

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .new)

        // then
        #expect(plan == .refuse(.tooLong(lines: SyntaxHighlighting.lineLimit + 1)))
    }

    @Test
    func `given a side at the line limit when it is assembled then it is highlighted`() {
        // given — the limit itself is inside it, which is the half of a boundary that an
        // off-by-one gets wrong silently.
        let lines = (1...SyntaxHighlighting.lineLimit).map {
            aLine(kind: .context, old: $0, new: $0, text: "x")
        }
        let diff = aDiff(hunks: [aHunk(lines: lines)])

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .new)

        // then
        #expect(plan.source?.lineNumbers.count == SyntaxHighlighting.lineLimit)
    }

    @Test
    func `given a side larger than the limit when it is assembled then it is refused by size`() {
        // given — few lines, each enormous, which is the minified-file case the line limit alone
        // does not catch. One byte over the limit.
        let text = String(repeating: "a", count: SyntaxHighlighting.byteLimit + 1)
        let diff = aDiff(hunks: [aHunk(lines: [aLine(kind: .context, old: 1, new: 1, text: text)])])

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .new)

        // then
        #expect(plan == .refuse(.tooLarge(bytes: SyntaxHighlighting.byteLimit + 1)))
    }

    @Test
    func `given a side measured in bytes rather than characters when it is assembled then the measurement is utf8`() {
        // given — the limit is a size in memory, and a multi-byte character costs what it costs.
        // Three bytes each, so a third of the limit in characters is over the whole of it in bytes.
        let characters = SyntaxHighlighting.byteLimit / 3 + 1
        let diff = aDiff(hunks: [
            aHunk(lines: [aLine(kind: .context, old: 1, new: 1, text: String(repeating: "図", count: characters))])
        ])

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .new)

        // then — a third of the limit in characters, and over it in bytes. Counting characters
        // would have highlighted this one.
        #expect(characters < SyntaxHighlighting.byteLimit)
        #expect(plan == .refuse(.tooLarge(bytes: characters * 3)))
    }

    @Test
    func `given a wholly added file when the old side is assembled then there is nothing to highlight`() {
        // given — every line is an addition, so the old side has no lines at all.
        let diff = aDiff(hunks: [
            aHunk(lines: [
                aLine(kind: .addition, old: nil, new: 1, text: "let a = 1"),
                aLine(kind: .addition, old: nil, new: 2, text: "let b = 2")
            ])
        ])

        // when
        let plan = SyntaxHighlighting.plan(for: diff, side: .old)

        // then — named rather than answered with an empty string, because lexing nothing is work
        // with a cache entry behind it and the phone has a reason not to start it.
        #expect(plan == .refuse(.nothingOnThisSide))
    }

    // MARK: - What invalidates a cached side

    @Test
    func `given two sides of one file when their keys are made then the keys differ`() {
        // given
        let diff = aDiff(hunks: [aHunk()])

        // when
        let old = SyntaxHighlighting.key(for: diff, side: .old, appearance: .light, pointSize: 11)
        let new = SyntaxHighlighting.key(for: diff, side: .new, appearance: .light, pointSize: 11)

        // then — the two sides of one file are different text and would otherwise share an entry.
        #expect(old != new)
        #expect(old?.side == .old)
    }

    @Test
    func `given one side in two appearances when the keys are made then they differ`() {
        // given — the colours are baked into what the highlighter returns, so an appearance change
        // is a different answer to the same question rather than the same answer restyled.
        let diff = aDiff(hunks: [aHunk()])

        // when
        let light = SyntaxHighlighting.key(for: diff, side: .new, appearance: .light, pointSize: 11)
        let dark = SyntaxHighlighting.key(for: diff, side: .new, appearance: .dark, pointSize: 11)

        // then
        #expect(light != dark)
    }

    @Test
    func `given one side at two point sizes when the keys are made then they differ`() {
        // given — the font is an attribute of what comes back, so the code size is part of the
        // question. `SPEC.md` §10 makes it a setting of its own.
        let diff = aDiff(hunks: [aHunk()])

        // when
        let small = SyntaxHighlighting.key(for: diff, side: .new, appearance: .light, pointSize: 11)
        let large = SyntaxHighlighting.key(for: diff, side: .new, appearance: .light, pointSize: 14)

        // then
        #expect(small != large)
    }

    @Test
    func `given a side that has been expanded when its key is made then it differs from before`() {
        // given — **this is what 0.4.0 broke and nothing had to answer for until now.** Expansion
        // splices context lines into a hunk that the parser never saw, so the string the lexer
        // reads grows — while `contentHash` is a fact about the *file*, which did not change. A key
        // carrying only the hash would hand back the entry made before the expansion and index it
        // against lines that are no longer where it thinks they are.
        let before = aDiff(hunks: [aHunk()])
        let after = aDiff(hunks: [
            aHunk(lines: [aLine(kind: .context, old: 9, new: 9, text: "import Foundation")] + aHunk().lines)
        ])

        // when
        let first = SyntaxHighlighting.key(for: before, side: .new, appearance: .light, pointSize: 11)
        let second = SyntaxHighlighting.key(for: after, side: .new, appearance: .light, pointSize: 11)

        // then — same file, same hash, different question.
        #expect(before.file.contentHash == after.file.contentHash)
        #expect(first != second)
    }

    @Test
    func `given a file with no language when its key is made then there is none`() {
        // given — a key names the language it was lexed as, and there is no entry to make without
        // one. Refusing here rather than defaulting is what stops a plain-rendered side occupying a
        // cache slot that a later, real language would collide with.
        let diff = aDiff(hunks: [aHunk()], language: nil)

        // when
        let key = SyntaxHighlighting.key(for: diff, side: .new, appearance: .light, pointSize: 11)

        // then
        #expect(key == nil)
    }

    // MARK: - Getting the answer back onto the lines

    @Test
    func `given highlighted lines when they are indexed then each lands on the number it came from`() {
        // given — the gapped file, so the numbers the result is filed under are not its offsets.
        let source = HighlightSource(side: .new, text: "struct A {\nstruct B {", lineNumbers: [10, 50])

        // when
        let indexed = source.indexed(["A", "B"])

        // then
        #expect(indexed == [10: "A", 50: "B"])
    }

    @Test
    func `given a highlighter that answered with the wrong number of lines when they are indexed then none is`() {
        // given — the lexer is a JavaScript engine behind a bridge and the string it is handed has
        // been through two splits; a result one line short would otherwise silently shift every
        // colour after it onto the wrong line.
        let source = HighlightSource(side: .new, text: "struct A {\nstruct B {", lineNumbers: [10, 50])

        // when
        let indexed = source.indexed(["A"])

        // then — nothing rather than something wrong. The side renders plain, which is the state
        // `SPEC.md` §10 already makes every side start in.
        #expect(indexed.isEmpty)
    }
}

// MARK: -

private func aDiff(hunks: [Hunk], language: String? = "swift") -> FileDiff {
    FileDiff(
        file: FileChange(
            id: FileID(rawValue: "f1"),
            path: "Sources/Reader.swift",
            oldPath: nil,
            status: .modified,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 1, deletions: 1),
            contentHash: String(repeating: "a", count: 64),
            estimatedLineCount: 3,
            isViewed: false,
            isTruncated: false,
            language: language
        ),
        hunks: hunks,
        oldLineCount: 40,
        newLineCount: 40,
        isTruncated: false,
        truncationReason: nil
    )
}

private func aHunk(lines: [DiffLine]? = nil) -> Hunk {
    Hunk(
        index: 0,
        oldStart: 10,
        oldCount: 3,
        newStart: 10,
        newCount: 3,
        sectionHeading: "final class Reader",
        lines: lines ?? [
            aLine(kind: .context, old: 10, new: 10, text: "final class Reader {"),
            aLine(kind: .deletion, old: 11, new: nil, text: "    var store: Store?"),
            aLine(kind: .addition, old: nil, new: 11, text: "    let store: Store"),
            aLine(kind: .context, old: 12, new: 12, text: "}")
        ]
    )
}

private func aLine(kind: DiffLineKind, old: Int?, new: Int?, text: String) -> DiffLine {
    DiffLine(
        kind: kind,
        oldNumber: old,
        newNumber: new,
        text: text,
        displayColumns: text.count,
        segments: nil
    )
}
