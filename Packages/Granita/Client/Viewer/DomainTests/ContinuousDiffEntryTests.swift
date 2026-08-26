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
