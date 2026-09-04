import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// A comment against the diff as it is now, which is the question design §7's stale row and its
/// amber list row both ask.
///
/// **Staleness is a fact about the pair, not about the comment**, so it is computed rather than
/// stored: the anchor is an address into a diff, and a diff arrives, is expanded, and is re-read.
/// A stored flag would have three writers and would be wrong the first time one of them did not run.
///
/// The distinction that carries the whole type is between *gone* and *not here yet*. A file still on
/// its way has no rows to match against, and calling that stale would put an amber row under every
/// file in a change set the moment it opened.
@Suite("Reviewed comment")
struct ReviewedCommentTests {

    @Test
    func `given the lines are still in the diff when the comment is judged then it is not stale`() {
        // given
        let entries = [ContinuousDiffEntry.ready(aDiff())]

        // when
        let reviewed = ReviewedComment.listing(of: [aComment(first: 11, last: 12)], against: entries)

        // then
        #expect(reviewed.map(\.isStale) == [false])
    }

    @Test
    func `given the lines are gone from the diff when the comment is judged then it is stale`() {
        // given — the agent rewrote the file, so the rows the reader wrote against are not in it.
        let entries = [ContinuousDiffEntry.ready(aDiff())]

        // when
        let reviewed = ReviewedComment.listing(of: [aComment(first: 900, last: 901)], against: entries)

        // then
        #expect(reviewed.map(\.isStale) == [true])
    }

    @Test
    func `given the file is no longer changed at all when the comment is judged then it is stale`() {
        // given — the agent reverted the file, so it is not in the change set. The comment is still
        // what the reader said and still goes in the document; what it has lost is a place to sit.
        let entries: [ContinuousDiffEntry] = []

        // when
        let reviewed = ReviewedComment.listing(of: [aComment(first: 11, last: 12)], against: entries)

        // then
        #expect(reviewed.map(\.isStale) == [true])
    }

    @Test
    func `given the file's diff has not arrived when the comment is judged then it is not stale yet`() {
        // given — the scroll names every file before it fetches any, so this is the ordinary state of
        // every file below the viewport. Calling it stale would put an amber row under most of a
        // change set the moment it opened, and take it back again as the batches landed.
        let entries = [ContinuousDiffEntry.awaiting(aDiff().file)]

        // when
        let reviewed = ReviewedComment.listing(of: [aComment(first: 11, last: 12)], against: entries)

        // then
        #expect(reviewed.map(\.isStale) == [false])
    }

    @Test
    func `given several comments when they are judged then each keeps its own answer and its order`() {
        // given
        let entries = [ContinuousDiffEntry.ready(aDiff())]
        let live = aComment(first: 11, last: 12, saying: "Still here.")
        let gone = aComment(first: 900, last: 901, saying: "Gone.")

        // when
        let reviewed = ReviewedComment.listing(of: [live, gone], against: entries)

        // then — the order is the caller's, because the model has already put it in the scroll's.
        #expect(reviewed.map(\.comment.text) == ["Still here.", "Gone."])
        #expect(reviewed.map(\.isStale) == [false, true])
    }

    @Test
    func `given a reviewed comment when its identity is asked for then it is the comment's own anchor`() {
        // given
        let entries = [ContinuousDiffEntry.ready(aDiff())]

        // when
        let reviewed = ReviewedComment.listing(of: [aComment(first: 11, last: 12)], against: entries)

        // then — so a list can be built from these directly rather than from a second key.
        #expect(reviewed.first?.id == reviewed.first?.comment.anchor)
    }

    // MARK: - Document order

    @Test
    func `given comments written out of order when they are ordered then they follow the scroll`() {
        // given — the reader wrote the second file's comment first, and both the list and the
        // document have to read the way the change set does rather than the way the afternoon went.
        let entries = [ContinuousDiffEntry.ready(aDiff()), ContinuousDiffEntry.ready(anotherDiff())]
        let second = anchored(file: anotherFile, at: position(old: 4), saying: "Two.")
        let first = anchored(at: position(old: 10, new: 11), saying: "One.")

        // when
        let ordered = ReviewedComment.ordered([second, first], against: entries)

        // then
        #expect(ordered.map(\.text) == ["One.", "Two."])
    }

    @Test
    func `given a deletion above an addition when they are ordered then the deletion still comes first`() {
        // given — **the case a line number cannot decide, and the one that made this function move.**
        // A hundred lines were cut early in this file, so the old side runs a hundred ahead of the
        // new: the deletion drawn at the top reports 105 and the addition under it reports 50.
        let entries = [ContinuousDiffEntry.ready(aFileThatDeletedALot())]
        let deletion = anchored(at: position(old: 105), reporting: 105, on: .old, saying: "Above.")
        let addition = anchored(at: position(new: 50), reporting: 50, on: .new, saying: "Below.")

        // when
        let ordered = ReviewedComment.ordered([addition, deletion], against: entries)

        // then — the deletion is drawn above the addition whatever their numbers say. Ordered on the
        // figure each one reports, 50 beats 105 and the document reads backwards — which is what the
        // sort did before it asked the diff.
        #expect(ordered.map(\.text) == ["Above.", "Below."])
    }

    @Test
    func `given two comments in one file when they are ordered then the earlier row comes first`() {
        // given — the context row at the top of the file, and the deletion under it.
        let entries = [ContinuousDiffEntry.ready(aDiff())]
        let lower = anchored(at: position(old: 11), saying: "Lower.")
        let upper = anchored(at: position(old: 10, new: 11), saying: "Upper.")

        // when
        let ordered = ReviewedComment.ordered([lower, upper], against: entries)

        // then
        #expect(ordered.map(\.text) == ["Upper.", "Lower."])
    }

    @Test
    func `given a comment on a file that is no longer changed when they are ordered then it goes last`() {
        // given — the agent reverted a file after the reader commented on it. Still what they said
        // and still worth sending; what it cannot claim is a place in a scroll it is not part of.
        let entries = [ContinuousDiffEntry.ready(aDiff())]
        let gone = anchored(file: FileID(rawValue: "reverted"), at: position(old: 1), saying: "Orphan.")
        let present = anchored(at: position(old: 11), saying: "Present.")

        // when
        let ordered = ReviewedComment.ordered([gone, present], against: entries)

        // then
        #expect(ordered.map(\.text) == ["Present.", "Orphan."])
    }

    @Test
    func `given two comments the diff cannot place when they are ordered then the reported line decides`() {
        // given — neither has rows to be placed among, so the span each reports is the only thing
        // left. Both are unresolved, so at least they are being compared like for like.
        let entries = [ContinuousDiffEntry.ready(aDiff())]
        let lower = anchored(file: FileID(rawValue: "gone-a"), at: position(old: 30), reporting: 30, saying: "Lower.")
        let upper = anchored(file: FileID(rawValue: "gone-b"), at: position(old: 4), reporting: 4, saying: "Upper.")

        // when
        let ordered = ReviewedComment.ordered([lower, upper], against: entries)

        // then
        #expect(ordered.map(\.text) == ["Upper.", "Lower."])
    }

    @Test
    func `given a file whose diff has not arrived when its comments are ordered then they go last`() {
        // given — it is in the change set, so it is not stale; but there are no rows to place it
        // among yet, and inventing a position from a number is the defect this ordering exists to
        // avoid.
        let entries = [ContinuousDiffEntry.ready(aDiff()), ContinuousDiffEntry.awaiting(anotherDiff().file)]
        let waiting = anchored(file: anotherFile, at: position(old: 4), saying: "Not here yet.")
        let placed = anchored(at: position(old: 11), saying: "Placed.")

        // when
        let ordered = ReviewedComment.ordered([waiting, placed], against: entries)

        // then
        #expect(ordered.map(\.text) == ["Placed.", "Not here yet."])
    }
}

// MARK: -

private let aFile = FileID(rawValue: "the-one-being-read")
private let anotherFile = FileID(rawValue: "the-next-one-down")

private func position(old: Int? = nil, new: Int? = nil) -> DiffLinePosition {
    DiffLinePosition(oldNumber: old, newNumber: new)
}

/// A comment anchored to an **exact row**, for the ordering tests — where which row it is is the
/// whole answer, and a fixture naming a row the diff does not have would pass by failing to resolve.
private func anchored(
    file: FileID = aFile,
    at first: DiffLinePosition,
    reporting line: Int = 1,
    on side: DiffSide = .new,
    saying text: String
) -> ReviewComment {
    ReviewComment(
        anchor: CommentAnchor(file: file, first: first, last: first),
        path: "Sources/Api.swift",
        lines: CommentedLines(side: side, first: line, last: line),
        quotedLines: ["let refreshed = true"],
        text: text
    )
}

private func aComment(
    file: FileID = aFile,
    first: Int,
    last: Int,
    side: DiffSide = .new,
    saying text: String = "Why?"
) -> ReviewComment {
    ReviewComment(
        anchor: CommentAnchor(
            file: file,
            first: DiffLinePosition(oldNumber: first, newNumber: nil),
            last: DiffLinePosition(oldNumber: nil, newNumber: last)
        ),
        path: "Sources/Api.swift",
        lines: CommentedLines(side: side, first: first, last: last),
        quotedLines: ["let refreshed = true"],
        text: text
    )
}

/// A second file, so ordering across two of them is a question with an answer.
private func anotherDiff() -> FileDiff {
    diff(
        id: anotherFile,
        path: "Sources/Store.swift",
        lines: [
            DiffLine(kind: .deletion, oldNumber: 4, newNumber: nil, text: "let a = 1", displayColumns: 9, segments: nil),
            DiffLine(kind: .addition, oldNumber: nil, newNumber: 4, text: "let a = 2", displayColumns: 9, segments: nil)
        ]
    )
}

/// **The file the ordering defect needed.** A hundred lines were cut early, so the old side runs a
/// hundred ahead of the new: a deletion drawn near the top reports 105 and an addition below it
/// reports 50. Ordered by the figure each one shows, the lower row wins.
private func aFileThatDeletedALot() -> FileDiff {
    diff(
        id: aFile,
        path: "Sources/Api.swift",
        lines: [
            DiffLine(kind: .deletion, oldNumber: 105, newNumber: nil, text: "let legacy = true", displayColumns: 17, segments: nil),
            DiffLine(kind: .addition, oldNumber: nil, newNumber: 50, text: "let modern = true", displayColumns: 17, segments: nil)
        ]
    )
}

private func diff(id: FileID, path: String, lines: [DiffLine]) -> FileDiff {
    FileDiff(
        file: FileChange(
            id: id,
            path: path,
            oldPath: nil,
            status: .modified,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 1, deletions: 1),
            contentHash: String(repeating: "c", count: 64),
            estimatedLineCount: lines.count,
            isViewed: false,
            isTruncated: false,
            language: "swift"
        ),
        hunks: [
            Hunk(index: 0, oldStart: 1, oldCount: 1, newStart: 1, newCount: 1, sectionHeading: nil, lines: lines)
        ],
        oldLineCount: 200,
        newLineCount: 100,
        isTruncated: false,
        truncationReason: nil
    )
}

private func aDiff() -> FileDiff {
    FileDiff(
        file: FileChange(
            id: aFile,
            path: "Sources/Api.swift",
            oldPath: nil,
            status: .modified,
            isBinary: false,
            isSubmodule: false,
            stats: ChangeStats(filesChanged: 1, insertions: 1, deletions: 1),
            contentHash: String(repeating: "c", count: 64),
            estimatedLineCount: 3,
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
                    DiffLine(kind: .context, oldNumber: 10, newNumber: 11, text: "    func refresh() {", displayColumns: 20, segments: nil),
                    DiffLine(kind: .deletion, oldNumber: 11, newNumber: nil, text: "        let refreshed = false", displayColumns: 29, segments: nil),
                    DiffLine(kind: .addition, oldNumber: nil, newNumber: 12, text: "        let refreshed = true", displayColumns: 28, segments: nil)
                ]
            )
        ],
        oldLineCount: 60,
        newLineCount: 61,
        isTruncated: false,
        truncationReason: nil
    )
}
