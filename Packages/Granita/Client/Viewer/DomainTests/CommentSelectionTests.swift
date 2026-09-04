import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Which rows a comment covers, and how those rows are named afterwards.
///
/// **A row is addressed by the numbers it carries, not by where it sits.** Hunk expansion splices
/// twenty lines into the middle of a file and a re-read replaces every hunk, so an offset is an
/// address that stops pointing at the row the reader chose. Old numbers rise down the old side and
/// new numbers down the new one, which makes the pair unique within a file and unmoved by either.
///
/// The consequence is the rule these tests pin: **a row with no number on either side cannot be an
/// end of a selection.** There is exactly one such row — `\ No newline at end of file` — and the
/// existing gutter is what makes the rule honest rather than arbitrary, because design §4 draws no
/// figure for it and there is nothing to tap. A selection still *spans* it and the quote carries it.
///
/// **A conflict marker is not one of those, and the first version of these tests assumed it was.**
/// It reaches the parser behind an ordinary `+` or space and is re-tagged by its text, so it keeps
/// the numbers that prefix gave it — which is the right outcome, since a conflict is what a reader
/// most wants to point at. The fixture below is git's real shape for one.
@Suite("Comment selection")
struct CommentSelectionTests {

    // MARK: - The rows a pair of ends covers

    @Test
    func `given one end when the rows are asked for then it is the single row`() {
        // given
        let diff = aDiff()

        // when
        let rows = CommentSelection.rows(
            of: diff,
            from: DiffLinePosition(oldNumber: nil, newNumber: 12),
            to: DiffLinePosition(oldNumber: nil, newNumber: 12)
        )

        // then
        #expect(rows?.map(\.text) == ["        let refreshed = true"])
    }

    @Test
    func `given two ends when the rows are asked for then everything between them comes too`() {
        // given
        let diff = aDiff()

        // when — the deletion at old 11 through the context at old 12 / new 13.
        let rows = CommentSelection.rows(
            of: diff,
            from: DiffLinePosition(oldNumber: 11, newNumber: nil),
            to: DiffLinePosition(oldNumber: 12, newNumber: 13)
        )

        // then
        #expect(rows?.map(\.text) == [
            "        let refreshed = false",
            "        let refreshed = true",
            "        return refreshed"
        ])
    }

    @Test
    func `given the second end is above the first when the rows are asked for then they read downwards`() {
        // given — a reader long-presses a row and then taps one *above* it, which is a gesture the
        // screen cannot forbid and must not answer with nothing.
        let diff = aDiff()

        // when
        let rows = CommentSelection.rows(
            of: diff,
            from: DiffLinePosition(oldNumber: 12, newNumber: 13),
            to: DiffLinePosition(oldNumber: 11, newNumber: nil)
        )

        // then
        #expect(rows?.map(\.text) == [
            "        let refreshed = false",
            "        let refreshed = true",
            "        return refreshed"
        ])
    }

    @Test
    func `given a selection across two hunks when the rows are asked for then it runs through both`() {
        // given
        let diff = aDiff()

        // when — from the last row of the first hunk to the first row of the second.
        let rows = CommentSelection.rows(
            of: diff,
            from: DiffLinePosition(oldNumber: 12, newNumber: 13),
            to: DiffLinePosition(oldNumber: 40, newNumber: 41)
        )

        // then — the two hunks are contiguous in the drawn order even though the file between them
        // is not, which is what the quote then has to be honest about.
        #expect(rows?.map(\.text) == [
            "        return refreshed",
            "    func reload() {"
        ])
    }

    @Test
    func `given an end that is not in the diff when the rows are asked for then there are none`() {
        // given — the agent changed the file under a comment written against the old content, so the
        // row it named is gone.
        let diff = aDiff()

        // when
        let rows = CommentSelection.rows(
            of: diff,
            from: DiffLinePosition(oldNumber: 900, newNumber: 900),
            to: DiffLinePosition(oldNumber: nil, newNumber: 12)
        )

        // then
        #expect(rows == nil)
    }

    @Test
    func `given a numberless end when the rows are asked for then there are none`() {
        // given — the no-newline marker carries no number on either side, so nothing addresses it.
        let diff = aDiff()

        // when
        let rows = CommentSelection.rows(
            of: diff,
            from: DiffLinePosition(oldNumber: nil, newNumber: nil),
            to: DiffLinePosition(oldNumber: nil, newNumber: 12)
        )

        // then
        #expect(rows == nil)
    }

    // MARK: - A row's own address

    @Test
    func `given a context row when its position is taken then it carries both numbers`() {
        // given
        let row = aLine(kind: .context, old: 12, new: 13, text: "        return refreshed")

        // when - then
        #expect(DiffLinePosition.of(row) == DiffLinePosition(oldNumber: 12, newNumber: 13))
    }

    @Test
    func `given a conflict marker when its position is taken then it keeps the prefix's numbers`() {
        // given — git writes `+<<<<<<< HEAD` into a conflicted working tree, so the parser numbers
        // it as the addition it arrived as and only then re-tags it by its text. The rows a reader
        // most wants to point at stay addressable because of that.
        let row = aLine(kind: .conflictMarker, old: nil, new: 5, text: "<<<<<<< HEAD")

        // when - then
        #expect(DiffLinePosition.of(row) == DiffLinePosition(oldNumber: nil, newNumber: 5))
    }

    @Test
    func `given a no-newline marker when its position is taken then it has none`() {
        // given — the one row on neither side. Two of them appear in one hunk whenever a trailing
        // newline is added, which is what makes them indistinguishable and why neither can be an end.
        let row = aLine(kind: .noNewlineMarker, old: nil, new: nil, text: "No newline at end of file")

        // when - then
        #expect(DiffLinePosition.of(row) == nil)
    }

    // MARK: - How the rows are named

    @Test
    func `given rows on the new side when they are named then they are the new side's span`() {
        // given
        let rows = [
            aLine(kind: .deletion, old: 11, new: nil, text: "        let refreshed = false"),
            aLine(kind: .addition, old: nil, new: 12, text: "        let refreshed = true"),
            aLine(kind: .context, old: 12, new: 13, text: "        return refreshed")
        ]

        // when
        let named = CommentedLines.of(rows)

        // then — the new side wins wherever it exists at all, because an agent works on the file as
        // it is now and "line 12" has to mean the line it would open.
        #expect(named == CommentedLines(side: .new, first: 12, last: 13))
    }

    @Test
    func `given rows that are all deletions when they are named then they are the old side's span`() {
        // given — lines that exist nowhere in the working copy. Reporting a new-side number for them
        // would point the agent at whatever now happens to sit there.
        let rows = [
            aLine(kind: .deletion, old: 11, new: nil, text: "        let refreshed = false"),
            aLine(kind: .deletion, old: 12, new: nil, text: "        return refreshed")
        ]

        // when
        let named = CommentedLines.of(rows)

        // then
        #expect(named == CommentedLines(side: .old, first: 11, last: 12))
    }

    @Test
    func `given rows that carry no number at all when they are named then they cannot be`() {
        // given — the pair of no-newline markers a hunk carries when a trailing newline is added.
        // No end can address either and no gutter offers a figure for them.
        let rows = [
            aLine(kind: .noNewlineMarker, old: nil, new: nil, text: "No newline at end of file"),
            aLine(kind: .noNewlineMarker, old: nil, new: nil, text: "No newline at end of file")
        ]

        // when - then
        #expect(CommentedLines.of(rows) == nil)
    }

    // MARK: - The comment those rows make

    @Test
    func `given two ends and some words when a comment is made then it carries the file and the span`() {
        // given
        let diff = aDiff()

        // when
        let comment = CommentSelection.comment(
            on: diff,
            from: DiffLinePosition(oldNumber: 11, newNumber: nil),
            to: DiffLinePosition(oldNumber: nil, newNumber: 12),
            saying: "This flips the default. Was that deliberate?"
        )

        // then
        #expect(comment?.path == "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift")
        #expect(comment?.lines == CommentedLines(side: .new, first: 12, last: 12))
        #expect(comment?.text == "This flips the default. Was that deliberate?")
        #expect(
            comment?.anchor == CommentAnchor(
                file: FileID(rawValue: "the-one-being-read"),
                first: DiffLinePosition(oldNumber: 11, newNumber: nil),
                last: DiffLinePosition(oldNumber: nil, newNumber: 12)
            )
        )
    }

    @Test
    func `given a comment is made when its quote is read then it is the code with no diff markers`() {
        // given
        let diff = aDiff()

        // when
        let comment = CommentSelection.comment(
            on: diff,
            from: DiffLinePosition(oldNumber: 10, newNumber: 11),
            to: DiffLinePosition(oldNumber: 12, newNumber: 13),
            saying: "Why?"
        )

        // then — design §7 quotes the excerpt with `> ` and carries no `+` or `−`. What a comment is
        // about is these lines; which side they are on is what the numbers beside the path say. An
        // agent handed `+ func refresh()` has been handed a string that appears in no file.
        //
        // Snapshotted now rather than resolved at export: the agent is about to change exactly these
        // lines, and a quote re-derived afterwards shows its reply rather than the reader's question.
        #expect(comment?.quotedLines == [
            "    func refresh() {",
            "        let refreshed = false",
            "        let refreshed = true",
            "        return refreshed"
        ])
    }

    @Test
    func `given a selection across a conflict when a comment is made then the markers are quoted as content`() {
        // given — a conflicted working tree holds the markers literally, so git diffs them as
        // additions. Their prefix is what the quote has to put back, and the kind cannot say: the
        // parser re-tagged them by their text and threw the prefix away.
        let diff = aConflictedDiff()

        // when
        let comment = CommentSelection.comment(
            on: diff,
            from: DiffLinePosition(oldNumber: 4, newNumber: 4),
            to: DiffLinePosition(oldNumber: nil, newNumber: 8),
            saying: "Resolve this one in favour of HEAD."
        )

        // then — the markers are the file's own content in a conflicted working tree, so they are
        // quoted as themselves. Nothing is added in front of them.
        #expect(comment?.quotedLines == [
            "    let port = 8080",
            "<<<<<<< HEAD",
            "    let host = \"localhost\"",
            "=======",
            "    let host = \"127.0.0.1\""
        ])
        #expect(comment?.lines == CommentedLines(side: .new, first: 4, last: 8))
    }

    @Test
    func `given a no-newline marker inside the run when a comment is made then it keeps git's own prefix`() {
        // given — the marker sits between the deletion and the addition whenever a trailing newline
        // is added, so a selection across the change spans a row that is on neither side.
        let diff = aTrailingNewlineDiff()

        // when
        let comment = CommentSelection.comment(
            on: diff,
            from: DiffLinePosition(oldNumber: 2, newNumber: nil),
            to: DiffLinePosition(oldNumber: nil, newNumber: 2),
            saying: "Add the newline."
        )

        // then — the one row that keeps a prefix, because it is the one row that is not a line of the
        // file. The parser strips the two characters git wrote it behind, and quoted bare it reads as
        // a sentence of English in the middle of some code.
        #expect(comment?.quotedLines == [
            "let trailing = false",
            "\\ No newline at end of file",
            "let trailing = true"
        ])
        // The marker contributes no number, so the span is the addition's alone.
        #expect(comment?.lines == CommentedLines(side: .new, first: 2, last: 2))
    }

    @Test
    func `given a comment when its identity is asked for then it is the anchor`() throws {
        // given — the anchor being the identity is what makes a second tap on a commented run an
        // edit rather than a duplicate, and it is what a list of comments is keyed by.
        let diff = aDiff()

        // when
        let comment = try #require(CommentSelection.comment(
            on: diff,
            from: DiffLinePosition(oldNumber: 11, newNumber: nil),
            to: DiffLinePosition(oldNumber: nil, newNumber: 12),
            saying: "Was that deliberate?"
        ))

        // then
        #expect(comment.id == CommentAnchor(
            file: FileID(rawValue: "the-one-being-read"),
            first: DiffLinePosition(oldNumber: 11, newNumber: nil),
            last: DiffLinePosition(oldNumber: nil, newNumber: 12)
        ))
    }

    @Test
    func `given an end that is not in the diff when a comment is made then there is none`() {
        // given
        let diff = aDiff()

        // when
        let comment = CommentSelection.comment(
            on: diff,
            from: DiffLinePosition(oldNumber: 900, newNumber: 900),
            to: DiffLinePosition(oldNumber: nil, newNumber: 12),
            saying: "Nothing to attach this to."
        )

        // then
        #expect(comment == nil)
    }
}

// MARK: -

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

/// Two hunks with a gap between them, so a selection can be asked to cross one.
private func aDiff() -> FileDiff {
    aDiff(hunks: [
        Hunk(
            index: 0,
            oldStart: 10,
            oldCount: 3,
            newStart: 11,
            newCount: 3,
            sectionHeading: "func refresh()",
            lines: [
                aLine(kind: .context, old: 10, new: 11, text: "    func refresh() {"),
                aLine(kind: .deletion, old: 11, new: nil, text: "        let refreshed = false"),
                aLine(kind: .addition, old: nil, new: 12, text: "        let refreshed = true"),
                aLine(kind: .context, old: 12, new: 13, text: "        return refreshed")
            ]
        ),
        Hunk(
            index: 1,
            oldStart: 40,
            oldCount: 2,
            newStart: 41,
            newCount: 2,
            sectionHeading: "func reload()",
            lines: [
                aLine(kind: .context, old: 40, new: 41, text: "    func reload() {"),
                aLine(kind: .addition, old: nil, new: 42, text: "        cache.drop()")
            ]
        )
    ])
}

/// git's real shape for a conflict: the markers are working-tree content that HEAD does not have, so
/// they arrive as additions and are numbered as additions.
private func aConflictedDiff() -> FileDiff {
    aDiff(hunks: [
        Hunk(
            index: 0,
            oldStart: 4,
            oldCount: 2,
            newStart: 4,
            newCount: 6,
            sectionHeading: nil,
            lines: [
                aLine(kind: .context, old: 4, new: 4, text: "    let port = 8080"),
                aLine(kind: .conflictMarker, old: nil, new: 5, text: "<<<<<<< HEAD"),
                aLine(kind: .context, old: 5, new: 6, text: "    let host = \"localhost\""),
                aLine(kind: .conflictMarker, old: nil, new: 7, text: "======="),
                aLine(kind: .addition, old: nil, new: 8, text: "    let host = \"127.0.0.1\""),
                aLine(kind: .conflictMarker, old: nil, new: 9, text: ">>>>>>> theirs")
            ]
        )
    ])
}

/// A file that gained its trailing newline, which is where the no-newline marker lands in the middle
/// of a run rather than at the end of one.
private func aTrailingNewlineDiff() -> FileDiff {
    aDiff(hunks: [
        Hunk(
            index: 0,
            oldStart: 1,
            oldCount: 2,
            newStart: 1,
            newCount: 2,
            sectionHeading: nil,
            lines: [
                aLine(kind: .context, old: 1, new: 1, text: "let leading = true"),
                aLine(kind: .deletion, old: 2, new: nil, text: "let trailing = false"),
                aLine(kind: .noNewlineMarker, old: nil, new: nil, text: "No newline at end of file"),
                aLine(kind: .addition, old: nil, new: 2, text: "let trailing = true")
            ]
        )
    ])
}

private func aDiff(hunks: [Hunk]) -> FileDiff {
    FileDiff(
        file: FileChange(
            id: FileID(rawValue: "the-one-being-read"),
            path: "Packages/Granita/Client/Connection/Data/HttpServerPairing.swift",
            oldPath: nil,
            status: .modified,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 2, deletions: 1),
            contentHash: String(repeating: "c", count: 64),
            estimatedLineCount: 6,
            isViewed: false,
            isTruncated: false,
            language: "swift"
        ),
        hunks: hunks,
        oldLineCount: 60,
        newLineCount: 61,
        isTruncated: false,
        truncationReason: nil
    )
}
