import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// A whole file's diff — the hunk bands and the lines between them.
///
/// What this asserts that `DiffFileLinesSnapshotTests` cannot: that the band reads as *not code*
/// against the code above and below it, that a hunk git gave no heading still gets its band, that
/// the gutter is one width for the file rather than one per hunk, and **which bands carry an expand
/// control** — design §4 puts it on the trailing edge, and a hunk with no gap above or below it gets
/// none, which is a thing only a picture of two hunks side by side can show.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Diff file content")
@MainActor
struct DiffFileContentSnapshotTests {

    @Test(arguments: DiffFileCase.all, SnapshotLayout.all)
    func `given a file's hunks when they render then they match their baseline`(
        subject: DiffFileCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            DiffFileContent(diff: subject.diff, pointSize: layout.codePointSize) { _, _, _ in }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which case it captures, and so a failure names it too.
struct DiffFileCase: Sendable, CustomTestStringConvertible {

    let name: String
    let diff: FileDiff

    var testDescription: String { name }

    static let all: [DiffFileCase] = [
        // A band with git's heading and a band without one, in the same picture, so the two can be
        // compared rather than described.
        DiffFileCase(name: "two-hunks-one-unheaded", diff: aFileOf(aFileWithTwoHunks, newLineCount: 2_000)),

        // Two-figure numbers above four-figure ones. Sized per hunk, the column would step out as
        // the reader scrolled into the second one — a gutter that changes width mid-file, which is
        // the same class of thing as a title that changes while you scroll.
        DiffFileCase(
            name: "hunks-that-disagree-on-width",
            diff: aFileOf(aFileWhoseHunksDisagreeOnWidth, newLineCount: 2_000)
        ),

        // **A file whose hunks have nowhere left to go**, which is the control the two above need:
        // they photograph a band carrying two chevrons, and without this one the picture asserts
        // "a band has chevrons" rather than "a band has chevrons where there is a gap". One hunk,
        // from the first line of the file to the last.
        DiffFileCase(name: "a-hunk-with-no-gaps", diff: aWholeFileInOneHunk),

        // **A file that has only one side**, which is the gutter's own fallback and until now had
        // never been drawn. A wholly added file has no old number anywhere in it, so the width the
        // old column is sized from falls back to nothing; a wholly deleted file is the mirror. Both
        // are ordinary — an agent adding a file and an agent removing one — and design §4's "on a
        // deletion row the column is blank" has never been photographed over a whole file.
        DiffFileCase(name: "a-file-that-is-all-additions", diff: aFileThatIsAllAdditions),
        DiffFileCase(name: "a-file-that-is-all-deletions", diff: aFileThatIsAllDeletions)
    ]
}
