import ClientSettingsDomain
import ClientSettingsUi
import ClientViewerDomain
import CoreReviewDomain
import SwiftUI
import Testing

/// The review's two settings, in every state a reader can land in.
///
/// **The thing these baselines hold is that the screen never goes inert.** A closed laptop is the
/// normal condition here, so the controls stay live in `unreachable` and in `the-mac-refused` — they
/// are off in exactly two subjects, and both are cases where a value would have nowhere to go ever.
/// That is a rule no unit test can photograph.
///
/// **No focused subject, deliberately.** The design asks for one with the keyboard raised, and the
/// keyboard is geometry that arrives asynchronously and lands on whichever render is laying out when
/// it does — the review sheet's own column baseline was lost to exactly that, four CI runs running.
/// The field is the first row of the first section, so what a keyboard would prove is that the
/// section below scrolls away, and it is not worth a flaky suite to photograph.
@Suite("Review settings", .serialized)
@MainActor
struct ReviewSettingsViewSnapshotTests {

    @Test(arguments: SettingsCase.all, SnapshotLayout.all)
    func `given a settings state when it renders then it matches its baseline`(
        subject: SettingsCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        assertScreenSnapshot(
            ReviewSettingsView(
                openingLine: .constant(subject.openingLine),
                identifier: subject.identifier,
                isOpeningLineDefault: subject.isOpeningLineDefault,
                standing: subject.standing,
                macName: "MacBook Pro",
                appearance: subject.appearance,
                codeTheme: subject.codeTheme,
                onChoose: { _ in },
                onChooseAppearance: { _ in },
                onChooseCodeTheme: { _ in },
                onCommitOpeningLine: {},
                onReset: {},
                onPair: {},
                onClose: {}
            ),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

struct SettingsCase: Sendable, CustomTestStringConvertible {

    let name: String
    let openingLine: String
    var identifier: ReviewIdentifier = .letters
    var isOpeningLineDefault = false
    let standing: ReviewSettingsStanding

    /// The fourth section's two values, defaulted so that the nine states above stay about the review.
    ///
    /// **`system` and Xcode's pair for every existing subject**, which is what an app nobody has
    /// configured draws — so the nine baselines these replace differ from their old selves by one
    /// section and by nothing else.
    var appearance: AppAppearance = .system
    var codeTheme: CodeTheme = .default

    var testDescription: String { name }

    static let all: [SettingsCase] = [
        // A line the reader changed at some point. **Reset is present**, and its presence is half of
        // how the default is told apart — the other half being the footer sentence.
        //
        // **Every line here fits one row of an iPhone**, on purpose: the field grows vertically, and
        // the width a vertical field wraps against is not settled on its first layout. A sentence that
        // wrapped after "in" here wrapped after "this" on the CI runner, three renders out of four,
        // and a wrap is the one thing this screen has that a render can land on either side of.
        SettingsCase(
            name: "a-line-of-their-own",
            openingLine: "Review the work in this worktree.",
            standing: .settled
        ),

        // **The same screen with two differences**: the footer names the value as the default, and
        // there is no Reset row because there is nothing to reset. The field is full-ink editable
        // text in both — the difference is stated, never implied by greying the words.
        SettingsCase(
            name: "never-changed",
            openingLine: ReviewSettings.defaultOpeningLine,
            isOpeningLineDefault: true,
            standing: .settled
        ),

        // **One footer sentence replaced and nothing else.** No spinner, no disabled control, and no
        // confirmation afterwards: a LAN write that succeeds in 40ms should not leave a mark.
        SettingsCase(
            name: "saving",
            openingLine: "Review the work in this worktree.",
            standing: .saving
        ),

        // **The state that makes this screen hard.** Editable and queued, not read-only: a closed
        // laptop is the normal condition, and read-only here would make the two controls unusable
        // for most of the time this app is open.
        SettingsCase(
            name: "the-mac-is-away",
            openingLine: "Reply to each point by its letter.",
            identifier: .numbers,
            standing: .queued
        ),

        // The two copies disagree and this phone's is the one that will be exported. The store's own
        // words go underneath ours rather than in place of them.
        SettingsCase(
            name: "the-mac-refused",
            openingLine: "Reply to each point by its letter.",
            standing: .refused(reason: "the document on disk could not be read")
        ),

        // **Off rather than absent**, because the screen still has to be findable — and a Mac that
        // predates these will answer for everything else on it.
        SettingsCase(
            name: "the-mac-is-too-old",
            openingLine: ReviewSettings.defaultOpeningLine,
            isOpeningLineDefault: true,
            standing: .tooOld
        ),

        // **Reachable and inert.** Discoverability was the real half of that question; operability
        // is not, because a queued value needs an addressee and this reader has none. The receipt is
        // gone too — it would be a receipt for a review that cannot exist.
        SettingsCase(
            name: "no-mac-at-all",
            openingLine: ReviewSettings.defaultOpeningLine,
            isOpeningLineDefault: true,
            standing: .noMac
        ),

        // **Cleared to nothing, which is a legal answer rather than a mistake**: the document then
        // begins at its first comment, and the receipt has to show that rather than an empty line
        // where the opening one was. The only subject that draws the receipt's other shape.
        SettingsCase(name: "no-opening-line", openingLine: "", standing: .settled),

        // **A refusal the store had no words for.** `documentIsFromANewerVersion` carries no
        // diagnostic, so the footer has to finish its own sentence rather than trail off where the
        // small print would have been. The only subject that draws that half of it.
        SettingsCase(
            name: "the-mac-refused-plainly",
            openingLine: "Reply to each point by its letter.",
            standing: .refused(reason: nil)
        ),

        // **A pair the reader chose**, which differs from `a-line-of-their-own` by one word and eight
        // colours. There is no Reset row and no badge for it: the list it came from still holds the
        // default one tap away, so *chosen* is not a state this section has to report.
        SettingsCase(
            name: "a-theme-of-their-own",
            openingLine: "Review the work in this worktree.",
            standing: .settled,
            codeTheme: .stackOverflow
        ),

        // **The two subjects that would catch a preview that started following the environment.** Each
        // is rendered in both appearances by the layout axis, so `forced-light` in the dark layout is a
        // dark sheet whose picker says Light — and the *in use* marker has to stay on the left sample
        // in both of that subject's renders, because what it reports is the appearance being drawn
        // rather than the one the phone would have chosen.
        //
        // **They are the frames the `resolved(whenFollowing:)` call exists for.** A view that read the
        // picker's value would put the marker in the right place here and the wrong place on `system`,
        // which is the common case and the one no frame can catch by itself.
        SettingsCase(
            name: "forced-light",
            openingLine: "Review the work in this worktree.",
            standing: .settled,
            appearance: .light
        ),
        SettingsCase(
            name: "forced-dark",
            openingLine: "Review the work in this worktree.",
            standing: .settled,
            appearance: .dark
        )
    ]
}
