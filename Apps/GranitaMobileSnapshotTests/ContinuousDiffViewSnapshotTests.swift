import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// The screen this product exists for: every changed file in one scroll.
///
/// **What a baseline can hold here is the resting frame**, which is still the half that went wrong
/// twice: that a file whose diff has not arrived reserves its height instead of collapsing, that the
/// first file's header is where a pinned header sits, and that the conflicted file says so in its
/// header before the reader scrolls into the markers. Whether the scroll reflows is a question about
/// motion, and motion is the device's answer.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Continuous diff")
@MainActor
struct ContinuousDiffViewSnapshotTests {

    @Test(arguments: SnapshotLayout.all)
    func `given a change set partly arrived when it renders then it matches its baseline`(
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            ContinuousDiffView(
                entries: aChangeSetPartlyArrived,
                showsOldNumber: layout.isRegularWidth,
                onReading: { _ in }
            ),
            layout: layout,
            named: "a-change-set-partly-arrived"
        )
    }

    @Test(arguments: SnapshotLayout.all)
    func `given nothing has arrived yet when it renders then every file still holds its place`(
        layout: SnapshotLayout
    ) {
        // given — the first frame after the change set lands and before any diff does. Every file is
        // named and none is drawn, which is deliberately **not** a spinner: five are in flight at
        // once, the reader is not blocked on any of them, and a column of spinners scrolling past is
        // the app describing its own plumbing.
        let entries = aChangeSetPartlyArrived.map { ContinuousDiffEntry.awaiting($0.file) }

        // when - then
        assertScreenSnapshot(
            ContinuousDiffView(entries: entries, showsOldNumber: layout.isRegularWidth, onReading: { _ in }),
            layout: layout,
            named: "nothing-arrived-yet"
        )
    }
}
