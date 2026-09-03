import ClientViewerUi
import SwiftUI
import Testing

/// The three small things §7 adds to the bottom and the middle of the diff: the instruction bar a
/// held row raises, the capsule that is the phone's way into the review, and the row a comment whose
/// lines are gone falls back to.
///
/// **The bar and the capsule share one position and can never both be true**, which is why they are
/// photographed apart: what a baseline can hold about them is what each looks like in the corner they
/// take turns in, and the screen's own suite is where the turn-taking is asserted.
@Suite("Comment affordances")
@MainActor
struct CommentAffordancesSnapshotTests {

    @Test(arguments: SnapshotLayout.all)
    func `given a row is held when the bar renders then it matches its baseline`(layout: SnapshotLayout) {
        // given - when - then
        assertScreenSnapshot(
            CommentInstructionBar(anchorLabel: "Turbine.swift:41", onCancel: {})
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom),
            layout: layout,
            named: "a-held-row"
        )
    }

    @Test(arguments: CapsuleCase.all, SnapshotLayout.all)
    func `given a comment count when the capsule renders then it matches its baseline`(
        subject: CapsuleCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            ReviewCapsule(count: subject.count, onOpen: {})
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing),
            layout: layout,
            named: subject.name
        )
    }

    @Test(arguments: SnapshotLayout.all)
    func `given a comment whose lines are gone when its row renders then it matches its baseline`(
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            StaleCommentRow(count: 1, line: 6, onOpenReview: {})
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top),
            layout: layout,
            named: "a-stale-comment"
        )
    }
}

// MARK: -

struct CapsuleCase: Sendable, CustomTestStringConvertible {

    let name: String
    let count: Int

    var testDescription: String { name }

    static let all: [CapsuleCase] = [
        // The first save, which is the moment the capsule exists at all.
        CapsuleCase(name: "one-comment", count: 1),
        // Two figures, which is what the monospaced count is for: the word must not move when the
        // number grows.
        CapsuleCase(name: "twelve-comments", count: 12)
    ]
}
