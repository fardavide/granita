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
                jumpTarget: subject.jumpTarget,
                onReading: { _ in },
                onJumped: {},
                onSetViewed: { _, _ in },
                onSetOpen: { _, _ in },
                onExpand: { _, _, _ in },
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

    /// A file §3's selector has asked this scroll to go to.
    ///
    /// **This is the half of the jump a photograph can hold**, and the reason the scroll watches its
    /// target with `initial: true`: a baseline can say the third file's header is where the first
    /// file's was, which is the difference between a row that jumps and a row that does nothing.
    let jumpTarget: FileID?

    var testDescription: String { name }

    static let all: [DiffScreenCase] = [
        // The screen doing its job: two files fetched and one still on its way, holding its place.
        DiffScreenCase(
            name: "a-change-set-partly-arrived",
            state: .reading(aChangeSetPartlyArrived),
            jumpTarget: nil
        ),

        // **The selector's whole job, over a change set tall enough for the jump to have somewhere
        // to go — and to a file with somewhere left to go after it.** Two fixtures were wrong before
        // this one. The three files of `aChangeSetPartlyArrived` fit on one screen, so a scroll that
        // worked and a scroll that did nothing photographed identically. Then the target was the
        // *last* file, which cannot reach the top: the scroll clamps against the end of the content,
        // so where it stopped depended on how much of the lazy stack had been realised, and the
        // baseline moved between runs. A file with hundreds of rows under it lands exactly where it
        // was asked to.
        DiffScreenCase(
            name: "jumped-to-a-file",
            state: .reading(aChangeSetWorthATree.map(ContinuousDiffEntry.awaiting)),
            jumpTarget: aChangeSetWorthATree.dropFirst(3).first?.id
        ),

        // The same scroll with nothing asked of it, which is the control this pair needs: without it
        // the picture above asserts "the last file is at the top" and not "the jump put it there".
        DiffScreenCase(
            name: "not-jumped-to-a-file",
            state: .reading(aChangeSetWorthATree.map(ContinuousDiffEntry.awaiting)),
            jumpTarget: nil
        ),

        // A file the reader has marked read, which is now **a bar rather than a diff**: `SPEC.md`
        // §10 says a file marked viewed renders collapsed, and 0.3.0's toggle moved a circle and
        // left the diff open under it. The toggle is still the only writer of the mark — design §4
        // refuses to infer it, because an inferred "viewed" is the app lying about its one job.
        DiffScreenCase(
            name: "a-file-marked-viewed",
            state: .reading(aChangeSetPartlyArrived.enumerated().map { position, entry in
                position == 0 ? entry.viewed(true) : entry
            }),
            jumpTarget: nil
        ),

        // **A run of bars, which is what design §4 draws collapsing for**: four files shut for four
        // different reasons, and the sentence on each is what stops the reader opening a file to
        // learn there was nothing in it. Two of them carry no chevron, because there is nothing
        // behind a binary file or a rename that changed nothing.
        DiffScreenCase(name: "every-reason-a-file-is-shut", state: .reading(aChangeSetOfShutFiles), jumpTarget: nil),

        // The same scroll with the reader having opened one of them, which is the control the
        // picture above needs: without it a bar that opens and a bar that does nothing photograph
        // identically.
        //
        // **The blank below the second header is the point rather than a fault.** That file's diff
        // was deliberately not fetched — it is the *Load diff* case — so opening it turns the bar
        // into a header over 1,558 rows of reserved height, which is the same idiom every file that
        // has not arrived uses and is what stops the content below it moving when it does.
        DiffScreenCase(
            name: "a-shut-file-the-reader-opened",
            state: .reading(aChangeSetOfShutFiles.enumerated().map { position, entry in
                position == 1 ? entry.opened(true) : entry
            }),
            jumpTarget: nil
        ),

        // The first frame after the change set lands and before any diff does. Every file is named
        // and none is drawn, which is deliberately **not** a column of spinners: five are in flight
        // at once, the reader is blocked on none of them, and spinners scrolling past would be the
        // app describing its own plumbing.
        DiffScreenCase(
            name: "nothing-arrived-yet",
            state: .reading(aChangeSetPartlyArrived.map { ContinuousDiffEntry.awaiting($0.file) }),
            jumpTarget: nil
        ),

        // A request that has neither answered nor failed. Unlike a Bonjour browse this one finishes,
        // so a progress view is not a promise the screen cannot keep.
        DiffScreenCase(name: "loading", state: .loading, jumpTarget: nil),

        // The machine's own words in small print under our sentence, which is where a diagnostic
        // goes on every screen in this app.
        DiffScreenCase(
            name: "failed",
            state: .failed(.gitFailure(message: "fatal: unable to read index.lock")),
            jumpTarget: nil
        ),

        // A refusal the Mac spells deliberately, which carries no small print at all — the state
        // that would otherwise leave an empty caption slot nobody had photographed.
        DiffScreenCase(name: "failed-plainly", state: .failed(.worktreeGone), jumpTarget: nil),

        // Reached on purpose rather than by accident: the sidebar's *Show them anyway* is how a
        // reader opens a worktree they were told was clean, so this owes them a confirmation rather
        // than something to press.
        DiffScreenCase(name: "nothing-changed", state: .nothingChanged, jumpTarget: nil)
    ]
}
