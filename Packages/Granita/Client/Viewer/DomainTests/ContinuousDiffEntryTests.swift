import Testing

import CoreDiffDomain

@testable import ClientViewerDomain

/// The height a file holds before anyone has seen it, and the identity it keeps once they have.
///
/// Asserted directly rather than through the view that reads them: being *used* by something else
/// does not cover a computed property, and reserving the wrong number of rows is a defect whose
/// only symptom is content moving — which is the one thing no photograph of this screen can show.
@Suite("Continuous diff entry")
struct ContinuousDiffEntryTests {

    @Test
    func `given a file nobody has seen when it reserves space then it uses the Mac's own estimate`() {
        // given — the server counted the diff lines while it had the comparison open, which is the
        // one place the number is cheap.
        let entry = ContinuousDiffEntry.awaiting(aChangedFile(estimatedLineCount: 34))

        // when - then
        #expect(entry.reservedRows == 34)
    }

    @Test
    func `given a file the Mac estimated at nothing when it reserves space then it still holds a row`() {
        // given — a rename with no content change comes back with nothing to draw, and the header
        // above it still needs something under it. A zero-height section is a file that vanishes
        // from a list that named it.
        let entry = ContinuousDiffEntry.awaiting(aChangedFile(estimatedLineCount: 0))

        // when - then
        #expect(entry.reservedRows == 1)
    }

    @Test
    func `given a file whose diff arrived when it reserves space then it counts the lines it has`() {
        // given — from here the height is real and sticky for the session, which is what makes
        // scrolling back up incapable of reflowing.
        let entry = ContinuousDiffEntry.ready(
            FileDiff(
                file: aChangedFile(estimatedLineCount: 34),
                hunks: [aHunk(lines: 4), aHunk(lines: 3)],
                oldLineCount: 120,
                newLineCount: 121,
                isTruncated: false,
                truncationReason: nil
            )
        )

        // when - then — seven, not the thirty-four the estimate claimed: an estimate that survived
        // the arrival of the real thing would reserve space nothing fills.
        #expect(entry.reservedRows == 7)
    }

    @Test
    func `given a file whose batch was refused when it reserves space then it holds the estimate it always had`() {
        // given — design §9's one hard requirement of the third case: the box a failed file draws
        // into is the box it was already drawing into. A failure that answered differently here
        // would change the height on the way in, which is the reflow the whole screen is built to
        // forbid, arriving from the one direction nobody could press.
        let entry = ContinuousDiffEntry.failed(aChangedFile(estimatedLineCount: 34))

        // when - then
        #expect(entry.reservedRows == 34)
        #expect(entry.reservedRows == ContinuousDiffEntry.awaiting(aChangedFile(estimatedLineCount: 34)).reservedRows)
    }

    @Test
    func `given a file whose batch was refused when the loader asks then it is not in hand`() {
        // given — `isReady` is what the loader spends a batch slot against, and a failed file has
        // no hunks. It must not read as held, or a retry would step over the files it is for.
        let entry = ContinuousDiffEntry.failed(aChangedFile(estimatedLineCount: 9))

        // when - then
        #expect(entry.isReady == false)
        #expect(entry.isFailed)
    }

    @Test
    func `given a file still on its way when its batch is refused then it fails and keeps the reader's chevron`() {
        // given — the reader may have opened this file by hand while the batch was in flight, and a
        // refusal is the Mac answering a question asked before they touched anything.
        let entry = ContinuousDiffEntry.awaiting(aChangedFile(estimatedLineCount: 9)).opened(true)

        // when
        let failed = entry.failing()

        // then
        #expect(failed.isFailed)
        #expect(failed.openedByTheReader == true)
    }

    @Test
    func `given a file whose diff is already in hand when its batch is refused then it keeps the diff`() {
        // given — a batch never carries a file that is already held, so this is the branch that must
        // not happen rather than the one that does. Taking a drawn diff away on a later refusal
        // would blank content the reader is reading.
        let entry = ContinuousDiffEntry.ready(
            FileDiff(
                file: aChangedFile(estimatedLineCount: 34),
                hunks: [aHunk(lines: 4)],
                oldLineCount: 120,
                newLineCount: 121,
                isTruncated: false,
                truncationReason: nil
            )
        )

        // when
        let failed = entry.failing()

        // then
        #expect(failed.isReady)
        #expect(failed.isFailed == false)
    }

    @Test
    func `given a file that failed when the reader tries again then it is on its way once more`() {
        // given — *Try Again* is the only thing that empties the failed set, so this is the move
        // that puts a file back in front of `ContinuousDiffLoading`.
        let entry = ContinuousDiffEntry.failed(aChangedFile(estimatedLineCount: 9)).opened(true)

        // when
        let retrying = entry.retrying()

        // then
        #expect(retrying.isFailed == false)
        #expect(retrying.isReady == false)
        #expect(retrying.openedByTheReader == true)
    }

    @Test
    func `given a file that failed when its diff finally arrives then it is ready`() {
        // given — a retry that works has to land on a failed entry, not only on an awaiting one.
        let file = aChangedFile(estimatedLineCount: 34)
        let entry = ContinuousDiffEntry.failed(file)

        // when
        let arrived = entry.arrived(
            FileDiff(
                file: file,
                hunks: [aHunk(lines: 4)],
                oldLineCount: 120,
                newLineCount: 121,
                isTruncated: false,
                truncationReason: nil
            )
        )

        // then
        #expect(arrived.isReady)
        #expect(arrived.isFailed == false)
        #expect(arrived.reservedRows == 4)
    }

    @Test
    func `given a file that failed when the selector marks its subtree read then the mark lands`() {
        // given — the selector marks a subtree done from the same state, and a file whose batch was
        // refused is one of the files that subtree contains. All three cases have to answer, or the
        // mark is a control that works on some rows and not others.
        let entry = ContinuousDiffEntry.failed(aChangedFile(estimatedLineCount: 9))

        // when
        let viewed = entry.viewed(true)

        // then
        #expect(viewed.file.isViewed)
        #expect(viewed.isFailed)
    }

    @Test
    func `given a state when the scroll asks where it starts then only a readable one answers`() {
        // given — the position is stated rather than settled into, so every state has to have an
        // answer and three of the four have to answer with nothing rather than with a guess.
        let file = aChangedFile(estimatedLineCount: 9)

        // when - then
        #expect(ContinuousDiffState.reading([.awaiting(file)]).firstFile == file.id)
        #expect(ContinuousDiffState.reading([]).firstFile == nil)
        #expect(ContinuousDiffState.loading.firstFile == nil)
        #expect(ContinuousDiffState.nothingChanged.firstFile == nil)
        #expect(ContinuousDiffState.failed(.worktreeGone).firstFile == nil)
    }

    @Test
    func `given either case when it is identified then the identity is the file's own`() {
        // given — the scroll is a `ForEach` over these, so two entries for one file, or an identity
        // that changes when a diff arrives, is a row SwiftUI rebuilds from scratch under the reader.
        let file = aChangedFile(estimatedLineCount: 9)
        let awaiting = ContinuousDiffEntry.awaiting(file)
        let ready = ContinuousDiffEntry.ready(
            FileDiff(file: file, hunks: [], oldLineCount: 9, newLineCount: 9, isTruncated: false, truncationReason: nil)
        )

        // when - then
        #expect(awaiting.id == file.id)
        #expect(ready.id == awaiting.id)
        #expect(ready.file == awaiting.file)
    }
}

// MARK: -

private func aChangedFile(estimatedLineCount: Int) -> FileChange {
    FileChange(
        id: FileID(rawValue: "3f2a91c40b7e"),
        path: "Sources/Granita/Viewer.swift",
        oldPath: nil,
        status: .modified,
        isBinary: false,
        isSubmodule: false,
        stats: ChangeStats(filesChanged: 1, insertions: 21, deletions: 13),
        contentHash: String(repeating: "c", count: 64),
        estimatedLineCount: estimatedLineCount,
        isViewed: false,
        isTruncated: false,
        language: "swift"
    )
}

private func aHunk(lines count: Int) -> Hunk {
    Hunk(
        index: 0,
        oldStart: 1,
        oldCount: count,
        newStart: 1,
        newCount: count,
        sectionHeading: nil,
        lines: (0..<count).map { position in
            DiffLine(
                kind: .context,
                oldNumber: position + 1,
                newNumber: position + 1,
                text: "let line = \(position)",
                displayColumns: 13,
                segments: nil
            )
        }
    )
}
