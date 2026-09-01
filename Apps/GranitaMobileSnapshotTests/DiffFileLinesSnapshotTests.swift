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
            DiffFileLines(
                lines: subject.lines,
                highestNumber: max(
                    subject.lines.compactMap(\.oldNumber).max() ?? 0,
                    subject.lines.compactMap(\.newNumber).max() ?? 0
                ),
                pointSize: subject.pointSize
            )
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

    /// 11pt on the phone and 12pt beside the selector column, which is the review's iPad
    /// measurement. The gutter, the marker and the row height all derive from it, so the two sizes
    /// are two different grids rather than one grid scaled.
    let pointSize: CGFloat

    var testDescription: String { name }

    static let all: [DiffLinesCase] = [
        // The ordinary case, and the one the segmented pair lives in: the deletion and the addition
        // under it differ by one word, and what says so is a background over the row's own tint.
        //
        // **It is also where the review's first fault is photographed fixed.** The deletion carries
        // its old-side number now, where before it drew an empty gutter — so the two rows of the
        // pair both have something a reader can point at.
        DiffLinesCase(name: "a-changed-function", lines: aChangedFunction, pointSize: 11),

        // The same lines at the iPad's size, where 846pt of pane holds about 110 characters.
        DiffLinesCase(name: "a-changed-function-beside-the-selector", lines: aChangedFunction, pointSize: 12),

        // Wrap off means this line leaves the screen and the numbers do not follow it. The baseline
        // holds the resting position, which is the one where the defect showed: the code must run
        // past the trailing edge rather than truncate at it, and the gutter must still be at the
        // leading edge rather than pushed off it by the code's own width.
        //
        // **And it is the only case that photographs the fade and the indicator.** The review's
        // third fault is a line that ends at the bezel looking complete; what a baseline can hold is
        // that the last characters are fading rather than cut, and that the 3pt bar under the hunk
        // says there is more to the right.
        DiffLinesCase(name: "a-line-past-the-edge", lines: aLineThatRunsOffTheEdge, pointSize: 11),

        // The one status worth a badge, and here the row half of it: a full-width warning tint and
        // the marker text at semibold, so a reader scrolling finds them without reading them. Its
        // marker column is deliberately empty — a conflict marker is neither side of the comparison.
        DiffLinesCase(name: "a-conflicted-hunk", lines: aConflictedHunk, pointSize: 11),

        // Three lines that each measure differently from how they look, which is the case the row
        // height exists for: a taller row would misalign every number below it.
        DiffLinesCase(name: "the-awkward-lines", lines: theAwkwardLines, pointSize: 12),

        // **The column is sized from the larger side, and this is the file that proves it.** A
        // hundred lines deleted from the end leaves an old side running into four figures while the
        // new side stops at two — sized on the new maximum, the old numbers would not fit the column
        // they are drawn in.
        DiffLinesCase(name: "an-old-side-that-outruns-the-new", lines: anOldSideThatOutrunsTheNew, pointSize: 11)
    ]
}
