import ClientConnectionDomain
import ClientViewerDomain
import ClientViewerUi
import SwiftUI
import Testing

/// Design §9's bottom bar, in each state a reader can put it in and each one the Mac can.
///
/// **The component rather than the screen**, because the screen's baselines photograph it once and
/// this is the element whose whole job is to say four different things and offer three different
/// controls. A bar that said the same sentence to a revoked pairing and a dead network would look
/// exactly like this one in a picture of the screen.
///
/// Serialised with every other suite here: they share one window, and anything a render leaves
/// behind is the next render's input.
@Suite("Diff failure bar", .serialized)
@MainActor
struct DiffFailureBarSnapshotTests {

    @Test(arguments: FailureBarCase.all, SnapshotLayout.all)
    func `given a refused batch when the bar renders then it matches its baseline`(
        subject: FailureBarCase,
        layout: SnapshotLayout
    ) {
        // given - when - then — on the page the diff draws its cards on, because the bar's own
        // separation from that page is a hairline rather than its fill.
        //
        // **At its own height rather than pinned to the bottom of the device frame**, which is what
        // the screen's own baselines photograph. A component pushed hard against the bottom safe
        // area is read as bottom-bar chrome and draws its trailing control a second time at the top;
        // `DiffFailureBar` clears the home indicator for exactly that reason, and a test that put it
        // back against the edge would be asserting a position the screen never gives it.
        assertScreenSnapshot(
            DiffFailureBar(failure: subject.failure) { _ in }
                .frame(maxHeight: .infinity, alignment: .center)
                .background(Color(uiColor: .systemGroupedBackground)),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

struct FailureBarCase: Sendable, CustomTestStringConvertible {

    let name: String
    let failure: DiffBatchFailure

    var testDescription: String { name }

    static let all: [FailureBarCase] = [
        // The ordinary shape: one request carried five files and none of them arrived.
        FailureBarCase(
            name: "five-files-out-of-reach",
            failure: DiffBatchFailure(
                failure: .unreachable(diagnostic: "NSURLErrorDomain -1004"),
                files: ["PinnedCertificate.swift", "GranitaRouter.swift", "WordDiff.swift", "DiffModels.swift", "project.yml"],
                isRetrying: false,
                hasBeenTried: false
            )
        ),

        // **One file names itself**, which is the only case where the reader has a blank card and the
        // sentence can tell them which. From two upwards it counts instead.
        FailureBarCase(
            name: "one-file-named",
            failure: DiffBatchFailure(
                failure: .gitFailure(message: "fatal: unable to read index.lock"),
                files: ["ContinuousDiffView.swift"],
                isRetrying: false,
                hasBeenTried: false
            )
        ),

        // Pressed. The stock indicator takes the control's slot — the one place a spinner is honest
        // on this screen, because the reader asked for exactly this one thing.
        FailureBarCase(
            name: "trying-again",
            failure: DiffBatchFailure(
                failure: .unreachable(diagnostic: "NSURLErrorDomain -1004"),
                files: ["PinnedCertificate.swift", "GranitaRouter.swift", "WordDiff.swift"],
                isRetrying: true,
                hasBeenTried: true
            )
        ),

        // **Both lines change on the second refusal**, which is the assertion: the first says it is
        // the second time and the second stops naming the reason and starts naming the remedy.
        FailureBarCase(
            name: "refused-a-second-time",
            failure: DiffBatchFailure(
                failure: .unreachable(diagnostic: "NSURLErrorDomain -1004"),
                files: ["PinnedCertificate.swift", "GranitaRouter.swift", "WordDiff.swift"],
                isRetrying: false,
                hasBeenTried: true
            )
        ),

        // The worktree went while it was being read, so there is nothing on this screen left to
        // retry and the only move is out.
        FailureBarCase(
            name: "the-worktree-is-gone",
            failure: DiffBatchFailure(
                failure: .worktreeGone,
                files: ["PinnedCertificate.swift", "GranitaRouter.swift"],
                isRetrying: false,
                hasBeenTried: false
            )
        ),

        // **The case the bar exists in one place for.** Every later request fails too, so a *Try
        // Again* here would be a control that cannot work — and a per-file retry would have drawn
        // that dead control once per blank card.
        FailureBarCase(
            name: "the-pairing-was-revoked",
            failure: DiffBatchFailure(
                failure: .unauthorized,
                files: ["PinnedCertificate.swift", "GranitaRouter.swift"],
                isRetrying: false,
                hasBeenTried: false
            )
        )
    ]
}
