import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// A whole file's diff — the hunk bands and the lines between them.
///
/// What this asserts that `DiffFileLinesSnapshotTests` cannot: that the band reads as *not code*
/// against the code above and below it, that a hunk git gave no heading still gets its band, and
/// that the gutter is one width for the file rather than one per hunk.
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
            DiffFileContent(hunks: subject.hunks, showsOldNumber: layout.isRegularWidth)
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
    let hunks: [Hunk]

    var testDescription: String { name }

    static let all: [DiffFileCase] = [
        // A band with git's heading and a band without one, in the same picture, so the two can be
        // compared rather than described.
        DiffFileCase(name: "two-hunks-one-unheaded", hunks: aFileWithTwoHunks),

        // Two-figure numbers above four-figure ones. Sized per hunk, the column would step out as
        // the reader scrolled into the second one — a gutter that changes width mid-file, which is
        // the same class of thing as a title that changes while you scroll.
        DiffFileCase(name: "hunks-that-disagree-on-width", hunks: aFileWhoseHunksDisagreeOnWidth)
    ]
}
