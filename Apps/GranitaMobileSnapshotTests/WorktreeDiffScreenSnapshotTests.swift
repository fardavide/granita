import ClientViewerDomain
import ClientViewerPresentation
import ClientViewerUi
import CoreDiffDomain
import SwiftUI
import Testing

/// The screen a chosen worktree lands on, composed the way the composition root composes it: design
/// §4's scroll, and design §3's selector as a drawer on the phone and a column on the iPad.
///
/// **What this suite asserts that the split screen's cannot** is the two states the reader puts it
/// in. The composition is photographed there, inside the columns it really has; here the drawer is
/// up, and here the refusal a mark can come back with is on screen — neither of which a picture of
/// the resting screen contains, and both of which are what the reader sees the moment they use the
/// thing.
///
/// **Serialised**, for the reason the other two screen suites are: these await a load before they
/// draw, and a suspension on the main actor is where another rendering test can take the key window
/// this one is about to photograph.
@Suite("Worktree diff screen", .serialized)
@MainActor
struct WorktreeDiffScreenSnapshotTests {

    @Test(arguments: SnapshotLayout.all)
    func `given a change set when the screen is rendered then it matches its baseline`(
        layout: SnapshotLayout
    ) async {
        // given — loaded before rendering, so the raster is settled rather than a race between the
        // screen's own `.task` and the shutter.
        let model = await aLoadedViewerModel(of: aChangeSetToSelectFrom, in: layout)

        // when - then — the phone gets the toolbar's *7 files*; the iPad gets the column instead,
        // which is why that button is absent there rather than duplicated.
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-change-set")
    }

    /// **The drawer is up in this one, and you cannot see it — which is the assertion.**
    ///
    /// A hosted view presents a sheet into a window of its own and the raster does not include it,
    /// so what this holds is the screen *behind* the drawer: design §3's argument for a drawer over
    /// a modal is that the diff is still there and still scrolling, undimmed, and an undimmed diff
    /// is precisely what a picture can say. Whether it scrolls under a thumb while the list is up is
    /// the half only a device answers, and it is in `status.md`.
    ///
    /// What it must **not** become is a second name for the resting screen. If this baseline ever
    /// stops differing from `a-change-set` in the toolbar or the dimming, it is asserting nothing
    /// and should go.
    @Test(arguments: SnapshotLayout.all)
    func `given the drawer is up when the screen is rendered then the diff behind it is undimmed`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(of: aChangeSetToSelectFrom, in: layout)
        model.showSelector(true)

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "the-drawer-is-up")
    }

    /// **A file this phone cannot colour, drawn plain beside one it can.**
    ///
    /// The Mac names a file's language from its extension and the phone's copy of highlight.js is
    /// whatever shipped with the app, so a Mac updated ahead of the phone can name a language this
    /// bundle has never heard of — which is the one refusal in `HighlightrSyntaxHighlighter` that a
    /// rendered screen can reach, and the reason it is a check rather than a hope: the library
    /// assigns the result of a JavaScript call to a non-optional value, and highlight.js v11 throws
    /// for a language it does not know.
    ///
    /// What the picture holds is that the outcome is *plain code* rather than a blank, an error or a
    /// file drawn in some other language's colours.
    @Test(arguments: SnapshotLayout.all)
    func `given a language this phone cannot colour when the screen is rendered then the code is drawn plain`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(of: aChangeSetTheLexerCannotRead, in: layout)

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-language-we-cannot-colour")
    }

    /// **The count has two spellings and only one of them is the plural.** Left unphotographed it
    /// ships as *1 files* and is seen first by whoever changed one file.
    @Test(arguments: SnapshotLayout.all)
    func `given one changed file when the screen is rendered then the toolbar says so in the singular`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(of: Array(aChangeSetToSelectFrom.prefix(1)), in: layout)

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "one-changed-file")
    }

    /// **The toolbar button is absent here, and until now that was a claim in a comment.**
    ///
    /// A worktree with nothing in it has no file list, so a *Files* button would open an empty drawer
    /// and say nothing about why. The screen has never been rendered in any state but `reading`, so
    /// the branch that leaves it out had never been drawn — which is exactly the shape of the thing
    /// this project keeps finding: an argument nobody photographed.
    @Test(arguments: SnapshotLayout.all)
    func `given a clean worktree when the screen is rendered then it offers no way to a file list`(
        layout: SnapshotLayout
    ) async {
        // given — reached on purpose: the sidebar's *Show them anyway* is how a reader opens a
        // worktree they were told was clean.
        let model = await aLoadedViewerModel(of: [], in: layout)

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-clean-worktree")
    }

    /// The mark is written optimistically, so a refusal has to take it back **and say so** — a mark
    /// that moved and then silently moved back is the app disagreeing with the reader about the one
    /// thing it is for.
    @Test(arguments: SnapshotLayout.all)
    func `given the Mac refused a mark when the screen is rendered then it says the file is unchanged`(
        layout: SnapshotLayout
    ) async {
        // given — the fake refuses every write, which is what this Mac does when the file has moved
        // under the hash the mark was written against.
        let model = await aLoadedViewerModel(of: aChangeSetToSelectFrom, in: layout)
        if let file = aChangeSetToSelectFrom.first?.id {
            await model.setViewed(true, on: file)
        }

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-refused-mark")
    }

    /// **The read this screen used to do in silence.** Coming back to a worktree re-runs the
    /// `.task` that fetches the whole file list, and the files already drawn deliberately stay
    /// drawn while it runs — so until this baseline existed there was no picture in which anything
    /// said a request was out.
    ///
    /// What it holds is that the only difference from `a-change-set` is in the bar: the scroll is
    /// untouched, because a reflow is what `SPEC.md` §10 forbids and an indicator inserted into the
    /// list would be one.
    @Test(arguments: SnapshotLayout.all)
    func `given the file list is being read again when the screen is rendered then the toolbar says so`(
        layout: SnapshotLayout
    ) async {
        // given
        let (model, refresh) = await aRefreshingViewerModel(in: layout)
        // Cancelled on every path, because a read still parked when this returns is a read the next
        // suite renders against — and these suites share one window.
        defer { refresh.cancel() }

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "the-file-list-is-refreshing")
    }

    // MARK: - Design §9's two states inside a reserved card

    /// **The ordinary shape of a refused batch: several stopped blocks and one bar.**
    ///
    /// Every card carries its own sentence, because five files are blank and five files say why; the
    /// control is at the bottom edge once, because one request failed. This is also where the two
    /// halves are seen to be different sizes — each block is its own file's estimate, so nothing
    /// repeats at a fixed pitch.
    @Test(arguments: SnapshotLayout.all)
    func `given a batch the Mac refused when the screen is rendered then every blank card says so`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(
            of: aChangeSetToSelectFrom,
            holding: [],
            in: layout,
            refusing: .unreachable(diagnostic: "NSURLErrorDomain -1004")
        )

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-batch-that-failed")
    }

    /// **The one failure whose control is not a retry**, and the reason the bar lives in one place at
    /// all: a revoked pairing refuses every later request too, so *Try Again* there is a control that
    /// cannot work — and a per-file retry would have drawn that dead control once per blank card.
    @Test(arguments: SnapshotLayout.all)
    func `given the pairing was revoked when the screen is rendered then the bar offers pairing`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(
            of: aChangeSetToSelectFrom,
            holding: [],
            in: layout,
            refusing: .unauthorized
        )

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-batch-refused-outright")
    }

    /// **The second refusal, which is two different sentences rather than the same one again.** The
    /// first line says it is the second time and the second stops naming the reason and starts naming
    /// the remedy — a sentence the reader has not already read and acted on.
    @Test(arguments: SnapshotLayout.all)
    func `given a retry that failed again when the screen is rendered then the bar names the remedy`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(
            of: aChangeSetToSelectFrom,
            holding: [],
            in: layout,
            refusing: .unreachable(diagnostic: "NSURLErrorDomain -1004")
        )
        await model.retryDiffs()

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-batch-that-failed-twice")
    }

    // MARK: - Design §7's two corners

    /// **The capsule, and the fact that it is not in the toolbar.** Design §7.4's call 2: a toolbar
    /// hides on scroll and reading is exactly when the count changes, so the way into the review
    /// floats over the bottom trailing corner instead — and `primaryAction` keeps *12 files*, which
    /// is the only place the phone says how big the read is.
    ///
    /// **On the iPad this baseline is the other half of the same call**: no capsule there, a
    /// bubble-and-count in the toolbar instead, because a column already on screen needs no button to
    /// announce it and that toolbar does not hide.
    @Test(arguments: SnapshotLayout.all)
    func `given comments exist when the screen is rendered then the way into the review is on it`(
        layout: SnapshotLayout
    ) async {
        // given — the entries have to be `ready`, because a comment cannot attach to a file whose
        // diff has not arrived and a rail cannot be drawn beside rows that are not there.
        let model = await aLoadedViewerModel(
            of: aChangeSetPartlyArrived,
            holding: aReviewOfTheFirstFile,
            in: layout
        )

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-review-in-progress")
    }

    /// **The state Davide's gesture leaves the reader in, and the sentence that explains it.** One row
    /// is held and the app is waiting for a second tap that may never come — a state no iOS
    /// convention explains and that nothing in the scroll can, because every pixel of it is code.
    ///
    /// It also holds the other half of §7.4's argument: the bar and the capsule share this position
    /// and can never both be true, so a review in progress with a row held shows the bar and no
    /// capsule.
    @Test(arguments: SnapshotLayout.all)
    func `given a row is held when the screen is rendered then the bar explains it and the capsule stands aside`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(
            of: aChangeSetPartlyArrived,
            holding: aReviewOfTheFirstFile,
            in: layout
        )
        if let file = aChangeSetPartlyArrived.first?.id {
            model.longPressedGutter(aRowOfTheFirstFile, in: file)
        }

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-row-held")
    }

    /// **The iPad's review column, which takes the tree's place rather than sitting beside it.**
    /// Design §7.7's call 6, and the arithmetic is the argument: three columns at 1194pt leave the
    /// code about 60 characters. On the phone the same model state is a sheet, so the two phone
    /// layouts here photograph the diff behind it — which is the assertion that the sheet did not
    /// take the column's place by accident.
    @Test(arguments: SnapshotLayout.all)
    func `given the review is open when the screen is rendered then the iPad gives it the tree's column`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(
            of: aChangeSetPartlyArrived,
            holding: aReviewOfTheFirstFile,
            in: layout
        )
        model.showReview()

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "the-review-is-open")
    }

    /// **The amber row, in the scroll it actually belongs to.** Design §7.3 gives a comment whose
    /// anchor no longer resolves a 44pt row under its file's header, and every other baseline that
    /// holds a review anchors to rows the diff still has — so the branch that draws it ran in no test
    /// at all, and inverting the filter or unwiring the button would have left everything green.
    ///
    /// It is also where the chip and the rail are seen disagreeing on purpose: the header counts
    /// three comments, only two of which have rails, and the row under it is what accounts for the
    /// third.
    @Test(arguments: SnapshotLayout.all)
    func `given a comment whose lines are gone when the screen is rendered then its file says so`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(
            of: aChangeSetPartlyArrived,
            holding: aReviewWithOneCommentAdrift,
            in: layout
        )

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-comment-adrift")
    }

    /// **A picture in the scroll, which is the only place the card is photographed in situ.**
    ///
    /// `DiffImageCardSnapshotTests` renders the body on its own; this is the branch that chooses it
    /// — a file whose `FileDiff` has no hunks in it because git answered `Binary files … differ`,
    /// drawn as two frames rather than as the empty card that branch replaced.
    @Test(arguments: SnapshotLayout.all)
    func `given a changed picture when the screen is rendered then its card draws both versions`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(of: aChangeSetWithAPicture, in: layout)

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-changed-picture")
    }

    /// **The cover is up in this one, and you cannot see it — which is the same assertion the
    /// drawer's baseline makes.** A hosted view presents into a window of its own and the raster
    /// does not include it, so what this holds is the screen the reader comes back to when they
    /// press Done, and that the diff behind a cover is undimmed and unchanged.
    ///
    /// What it does hold that no other picture does is that the presentation is **built**: the
    /// binding resolves, the model still has the bytes, and the file is still in the change set to
    /// take a name from. A cover that could not build its content is a tap that opens a blank
    /// screen, and the raster of the screen behind it is the only evidence available here. The
    /// gesture itself is a thumb's answer and is in `status.md`.
    @Test(arguments: SnapshotLayout.all)
    func `given a picture is open when the screen is rendered then the diff behind it is undisturbed`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(of: aChangeSetWithAPicture, in: layout)
        let picture = FileID(
            repositoryRelativePath: "Apps/GranitaMobileSnapshotTests/__Snapshots__/the-drawer-is-up-iPhone-light.png"
        )
        model.openImage(.new, of: picture)

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-picture-is-open")
    }
}

// MARK: -

/// Wrapped the way the composition root wraps it, because a baseline of a screen out of its stack
/// asserts a toolbar nobody draws.
@MainActor
private func screen(of model: ClientViewerModel) -> some View {
    NavigationStack {
        WorktreeDiffScreen(worktreeName: "TLS pinning", model: model, onPairAgain: {})
    }
        // **Reduced Motion wherever a card is still on its way.** Design §9's sweep is an infinite
        // repeat, so a raster of it lands wherever the run loop happened to be — and the design says
        // in as many words that the still form is what a screenshot of this screen looks like. Asked
        // of the model rather than declared per test, so a state that gains an unarrived file cannot
        // forget. What the sweep does under a thumb is checked by pressing it, like every other
        // motion in this app.
        .environment(\._accessibilityReduceMotion, rendersStill(model))
}

/// Whether this screen holds a card whose sweep would otherwise be caught mid-crossing.
@MainActor
private func rendersStill(_ model: ClientViewerModel) -> Bool {
    guard case .reading(let entries) = model.state else { return false }
    return entries.contains { $0.isReady == false }
}
