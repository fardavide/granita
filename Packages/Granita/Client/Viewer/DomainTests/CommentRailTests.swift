import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// Which stretches of rail each hunk draws.
///
/// **The clipping is the whole of it, and it exists because a file is not one view.**
/// `DiffFileContent` lays out one `DiffFileLines` per hunk with torn expander rows between them, so
/// there is no coordinate space a rail could span — a comment across a hunk boundary has to become
/// two runs, each in its own hunk's row numbers, and each drawn by a view that knows nothing about
/// the other.
@Suite("Comment rail")
struct CommentRailTests {

    @Test
    func `given a comment inside one hunk when the runs are asked for then that hunk draws it whole`() {
        // given — rows 1 and 2 of the first hunk, which is old 11 through old 12.
        let diff = aDiff()
        let comment = aComment(from: position(old: 11), to: position(old: 12, new: 13))

        // when
        let runs = CommentRail.runs(of: diff.hunks[0], in: diff, comments: [comment], pending: nil)

        // then
        #expect(runs == [CommentRun(firstRow: 1, rowCount: 3, isPending: false)])
    }

    @Test
    func `given a comment inside one hunk when a later hunk is asked then it draws nothing`() {
        // given
        let diff = aDiff()
        let comment = aComment(from: position(old: 11), to: position(old: 12, new: 13))

        // when
        let runs = CommentRail.runs(of: diff.hunks[1], in: diff, comments: [comment], pending: nil)

        // then
        #expect(runs.isEmpty)
    }

    @Test
    func `given a comment across two hunks when each is asked then each draws its own part`() {
        // given — from the last row of the first hunk to the second row of the next one. They are
        // adjacent on screen and a whole file apart in the source.
        let diff = aDiff()
        let comment = aComment(from: position(old: 12, new: 13), to: position(new: 42))

        // when
        let first = CommentRail.runs(of: diff.hunks[0], in: diff, comments: [comment], pending: nil)
        let second = CommentRail.runs(of: diff.hunks[1], in: diff, comments: [comment], pending: nil)

        // then — the first hunk draws its last row; the second draws its first two.
        #expect(first == [CommentRun(firstRow: 3, rowCount: 1, isPending: false)])
        #expect(second == [CommentRun(firstRow: 0, rowCount: 2, isPending: false)])
    }

    @Test
    func `given a run held rather than saved when the runs are asked for then it is pending`() {
        // given — square caps mean pending and round caps mean saved, which is a shape difference so
        // the state survives a greyscale screenshot.
        let diff = aDiff()
        let pending = PendingComment(file: aFile, from: position(old: 11), to: position(new: 12))

        // when
        let runs = CommentRail.runs(of: diff.hunks[0], in: diff, comments: [], pending: pending)

        // then
        #expect(runs == [CommentRun(firstRow: 1, rowCount: 2, isPending: true)])
    }

    @Test
    func `given a run held backwards when the runs are asked for then it still reads downwards`() {
        // given — the reader held the lower row and tapped upwards, which the gesture keeps unordered
        // because ordering it needs the diff. This is the diff.
        let diff = aDiff()
        let pending = PendingComment(file: aFile, from: position(new: 12), to: position(old: 11))

        // when
        let runs = CommentRail.runs(of: diff.hunks[0], in: diff, comments: [], pending: pending)

        // then
        #expect(runs == [CommentRun(firstRow: 1, rowCount: 2, isPending: true)])
    }

    @Test
    func `given a comment and a held run when the runs are asked for then both are drawn in row order`() {
        // given
        let diff = aDiff()
        let comment = aComment(from: position(old: 12, new: 13), to: position(old: 12, new: 13))
        let pending = PendingComment(file: aFile, from: position(old: 10, new: 11), to: position(old: 10, new: 11))

        // when
        let runs = CommentRail.runs(of: diff.hunks[0], in: diff, comments: [comment], pending: pending)

        // then — sorted, so a `ForEach` over them draws top to bottom whatever order they arrived in.
        #expect(runs == [
            CommentRun(firstRow: 0, rowCount: 1, isPending: true),
            CommentRun(firstRow: 3, rowCount: 1, isPending: false)
        ])
    }

    @Test
    func `given a comment on another file when the runs are asked for then this one draws nothing`() {
        // given — the model holds the whole review, and every hunk of every file reads the same list.
        let diff = aDiff()
        let elsewhere = aComment(
            file: FileID(rawValue: "some-other-file"),
            from: position(old: 11),
            to: position(new: 12)
        )

        // when
        let runs = CommentRail.runs(of: diff.hunks[0], in: diff, comments: [elsewhere], pending: nil)

        // then
        #expect(runs.isEmpty)
    }

    @Test
    func `given a held run on another file when the runs are asked for then this one draws nothing`() {
        // given
        let diff = aDiff()
        let elsewhere = PendingComment(
            file: FileID(rawValue: "some-other-file"),
            from: position(old: 11),
            to: position(new: 12)
        )

        // when
        let runs = CommentRail.runs(of: diff.hunks[0], in: diff, comments: [], pending: elsewhere)

        // then
        #expect(runs.isEmpty)
    }

    @Test
    func `given a comment whose lines are gone when the runs are asked for then it draws nothing`() {
        // given — design §7.3's stale case. It has no rows, so it can have no rail; what it gets
        // instead is a 44pt amber row under the file's own header.
        let diff = aDiff()
        let stale = aComment(from: position(new: 900), to: position(new: 901))

        // when
        let runs = CommentRail.runs(of: diff.hunks[0], in: diff, comments: [stale], pending: nil)

        // then
        #expect(runs.isEmpty)
    }

    @Test
    func `given a hunk that is not in this diff when the runs are asked for then it draws nothing`() {
        // given — a hunk from a diff the batch replaced while the view was still holding the old one.
        // Unreachable in one pass and answered rather than trusted, because the alternative is index
        // arithmetic against a file that does not contain it.
        let diff = aDiff()
        let stranger = Hunk(
            index: 9,
            oldStart: 1,
            oldCount: 1,
            newStart: 1,
            newCount: 1,
            sectionHeading: nil,
            lines: [aLine(kind: .context, old: 1, new: 1, text: "let a = 1")]
        )
        let comment = aComment(from: position(old: 11), to: position(new: 12))

        // when - then
        #expect(CommentRail.runs(of: stranger, in: diff, comments: [comment], pending: nil).isEmpty)
    }

    @Test
    func `given no comments at all when the runs are asked for then there are none`() {
        // given - when - then
        let diff = aDiff()
        #expect(CommentRail.runs(of: diff.hunks[0], in: diff, comments: [], pending: nil).isEmpty)
    }
}

// MARK: -

private let aFile = FileID(rawValue: "the-one-being-read")

private func position(old: Int? = nil, new: Int? = nil) -> DiffLinePosition {
    DiffLinePosition(oldNumber: old, newNumber: new)
}

private func aComment(
    file: FileID = aFile,
    from: DiffLinePosition,
    to: DiffLinePosition
) -> ReviewComment {
    ReviewComment(
        anchor: CommentAnchor(file: file, first: from, last: to),
        path: "Sources/Api.swift",
        lines: CommentedLines(side: .new, first: 12, last: 12),
        quotedLines: ["let refreshed = true"],
        text: "Why?"
    )
}

private func aLine(kind: DiffLineKind, old: Int?, new: Int?, text: String) -> DiffLine {
    DiffLine(kind: kind, oldNumber: old, newNumber: new, text: text, displayColumns: text.count, segments: nil)
}

/// Two hunks, four rows then three, so a run can be asked to cross the boundary between them.
private func aDiff() -> FileDiff {
    FileDiff(
        file: FileChange(
            id: aFile,
            path: "Sources/Api.swift",
            oldPath: nil,
            status: .modified,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 2, deletions: 1),
            contentHash: String(repeating: "c", count: 64),
            estimatedLineCount: 7,
            isViewed: false,
            isTruncated: false,
            language: "swift"
        ),
        hunks: [
            Hunk(
                index: 0,
                oldStart: 10,
                oldCount: 3,
                newStart: 11,
                newCount: 3,
                sectionHeading: nil,
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
                newCount: 3,
                sectionHeading: nil,
                lines: [
                    aLine(kind: .context, old: 40, new: 41, text: "    func reload() {"),
                    aLine(kind: .addition, old: nil, new: 42, text: "        cache.drop()"),
                    aLine(kind: .context, old: 41, new: 43, text: "    }")
                ]
            )
        ],
        oldLineCount: 60,
        newLineCount: 61,
        isTruncated: false,
        truncationReason: nil
    )
}
