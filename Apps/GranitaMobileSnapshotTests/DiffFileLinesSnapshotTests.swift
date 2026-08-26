import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// Design §4's wrap-off scroll, in the four layouts it has to survive.
///
/// **A baseline cannot scroll, and that is not the limit it looks like.** What these assert is the
/// half a photograph can reach and the half that went wrong first: that the numbers are on screen at
/// the leading edge, that the code beside them is not truncated to the viewport, and that the tints
/// reach the trailing edge rather than stopping where the widest line does. Whether the gesture
/// feels right under a thumb is the device's question, and design §4 says so.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Diff file lines")
@MainActor
struct DiffFileLinesSnapshotTests {

    @Test(arguments: DiffLinesCase.all, SnapshotLayout.all)
    func `given a file's lines when they render then they match their baseline`(
        subject: DiffLinesCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            DiffFileLines(lines: subject.lines, showsOldNumber: subject.showsOldNumber)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which case it captures, and so a failure names it too.
struct DiffLinesCase: Sendable, CustomTestStringConvertible {

    let name: String
    let lines: [DiffLine]

    /// Design §4 keeps the new number on the phone and both on iPad, so both are photographed — the
    /// two devices are deliberately not showing the same gutter, and that is what lets the phone
    /// afford 51 characters where two columns would leave 41.
    let showsOldNumber: Bool

    var testDescription: String { name }

    static let all: [DiffLinesCase] = [
        // The ordinary case, and the one the segmented pair lives in: the deletion and the addition
        // under it differ by one word, and what says so is the *text* rather than a second box.
        DiffLinesCase(name: "a-changed-function", lines: aChangedFunction, showsOldNumber: false),

        // The same lines with both columns, which is what an iPad's 554pt of code affords and the
        // phone's 390 does not: 78pt of gutter against 39.
        DiffLinesCase(name: "a-changed-function-both-columns", lines: aChangedFunction, showsOldNumber: true),

        // Wrap off means this line leaves the screen and the numbers do not follow it. The baseline
        // holds the resting position, which is the one where the defect showed: the code must run
        // past the trailing edge rather than truncate at it, and the gutter must still be at the
        // leading edge rather than pushed off it by the code's own width.
        DiffLinesCase(name: "a-line-past-the-edge", lines: aLineThatRunsOffTheEdge, showsOldNumber: false),

        // The one status worth a badge, and here the row half of it: a full-width warning tint and
        // the marker text at semibold, so a reader scrolling finds them without reading them.
        DiffLinesCase(name: "a-conflicted-hunk", lines: aConflictedHunk, showsOldNumber: false),

        // Three lines that each measure differently from how they look, which is the case the row
        // height exists for: a taller row would misalign every number below it.
        DiffLinesCase(name: "the-awkward-lines", lines: theAwkwardLines, showsOldNumber: true)
    ]
}
