import ClientConnectionDomain
import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// The screen this product exists for, in every state it can be in.
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

    @Test(arguments: DiffScreenCase.all, SnapshotLayout.all)
    func `given a diff state when it renders then it matches its baseline`(
        subject: DiffScreenCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            ContinuousDiffView(
                state: subject.state,
                showsOldNumber: layout.isRegularWidth,
                onReading: { _ in },
                onRetry: {}
            ),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which state it captures, and so a failure names it too.
struct DiffScreenCase: Sendable, CustomTestStringConvertible {

    let name: String
    let state: ContinuousDiffState

    var testDescription: String { name }

    static let all: [DiffScreenCase] = [
        // The screen doing its job: two files fetched and one still on its way, holding its place.
        DiffScreenCase(name: "a-change-set-partly-arrived", state: .reading(aChangeSetPartlyArrived)),

        // The first frame after the change set lands and before any diff does. Every file is named
        // and none is drawn, which is deliberately **not** a column of spinners: five are in flight
        // at once, the reader is blocked on none of them, and spinners scrolling past would be the
        // app describing its own plumbing.
        DiffScreenCase(
            name: "nothing-arrived-yet",
            state: .reading(aChangeSetPartlyArrived.map { ContinuousDiffEntry.awaiting($0.file) })
        ),

        // A request that has neither answered nor failed. Unlike a Bonjour browse this one finishes,
        // so a progress view is not a promise the screen cannot keep.
        DiffScreenCase(name: "loading", state: .loading),

        // The machine's own words in small print under our sentence, which is where a diagnostic
        // goes on every screen in this app.
        DiffScreenCase(name: "failed", state: .failed(.gitFailure(message: "fatal: unable to read index.lock"))),

        // A refusal the Mac spells deliberately, which carries no small print at all — the state
        // that would otherwise leave an empty caption slot nobody had photographed.
        DiffScreenCase(name: "failed-plainly", state: .failed(.worktreeGone)),

        // Reached on purpose rather than by accident: the sidebar's *Show them anyway* is how a
        // reader opens a worktree they were told was clean, so this owes them a confirmation rather
        // than something to press.
        DiffScreenCase(name: "nothing-changed", state: .nothingChanged)
    ]
}
