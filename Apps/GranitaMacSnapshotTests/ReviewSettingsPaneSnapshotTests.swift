import Foundation
import Testing

import CoreReviewDomain
import ServerMacUi

/// The Review tab, which is the sixth pane and the only one whose values a phone also writes.
///
/// **The pair worth reading together is `never-changed` against `a-line-of-their-own`**: the same
/// two rows, with *Reset* live on exactly one of them. That is the whole of how the default is told
/// apart on this side, and a baseline is the only thing that can hold "this control is disabled
/// here and not there".
///
/// Main-actor isolated, and it must be, for the reason every suite in this bundle is: Swift Testing
/// runs `@Test` functions off the main actor and hosting a SwiftUI view touches AppKit from whatever
/// thread it lands on.
@Suite("Review settings tab")
@MainActor
struct ReviewSettingsPaneSnapshotTests {

    @Test(arguments: Case.all, MacAppearance.all)
    func `given a Review state when rendering then it matches its baseline`(
        subject: Case,
        appearance: MacAppearance
    ) {
        // given - when - then
        assertSettingsSnapshot(
            ReviewSettingsPane(
                openingLine: .constant(subject.openingLine),
                identifier: subject.identifier,
                isOpeningLineDefault: subject.isOpeningLineDefault,
                storedReviews: subject.storedReviews,
                storedComments: subject.storedComments,
                onChoose: { _ in },
                onCommitOpeningLine: {},
                onReset: {}
            ),
            appearance: appearance,
            named: subject.name
        )
    }

    struct Case: Sendable, CustomTestStringConvertible {

        let name: String
        let openingLine: String
        var identifier: ReviewIdentifier = .letters
        var isOpeningLineDefault = false
        var storedReviews = 0
        var storedComments = 0

        var testDescription: String { name }

        static let all: [Case] = [
            // Nothing chosen and nothing written. **Reset is drawn and disabled**, which is where
            // this pane and the phone's screen part company on purpose: a window has room to show a
            // control that is not available, and a grouped row on a phone does not.
            Case(
                name: "never-changed",
                openingLine: ReviewSettings.defaultOpeningLine,
                isOpeningLineDefault: true
            ),

            // A line of the reader's own, with Reset live and the sample following it.
            Case(
                name: "a-line-of-their-own",
                openingLine: "Review the uncommitted work in this worktree.",
                storedReviews: 2,
                storedComments: 9
            ),

            // **Figures rather than letters, which is the sample earning its place**: the reader can
            // see the labels changed without copying anything.
            Case(
                name: "figures-chosen",
                openingLine: "Reply to each numbered point.",
                identifier: .numbers,
                storedReviews: 2,
                storedComments: 9
            ),

            // A review cleared to nothing is a legal answer — the document then begins at its first
            // comment — so the sample drops its first line rather than showing an empty one.
            Case(name: "no-opening-line", openingLine: "", storedReviews: 1, storedComments: 3)
        ]
    }
}
