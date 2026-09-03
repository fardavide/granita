import ClientViewerDomain
import ClientViewerPresentation
import ClientViewerUi
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
        let model = await aLoadedViewerModel(of: aChangeSetToSelectFrom)

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
        let model = await aLoadedViewerModel(of: aChangeSetToSelectFrom)
        model.showSelector(true)

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "the-drawer-is-up")
    }

    /// **The count has two spellings and only one of them is the plural.** Left unphotographed it
    /// ships as *1 files* and is seen first by whoever changed one file.
    @Test(arguments: SnapshotLayout.all)
    func `given one changed file when the screen is rendered then the toolbar says so in the singular`(
        layout: SnapshotLayout
    ) async {
        // given
        let model = await aLoadedViewerModel(of: Array(aChangeSetToSelectFrom.prefix(1)))

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
        let model = await aLoadedViewerModel(of: [])

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
        let model = await aLoadedViewerModel(of: aChangeSetToSelectFrom)
        if let file = aChangeSetToSelectFrom.first?.id {
            await model.setViewed(true, on: file)
        }

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "a-refused-mark")
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
        let model = await aLoadedViewerModel(of: aChangeSetPartlyArrived, holding: aReviewOfTheFirstFile)

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
        let model = await aLoadedViewerModel(of: aChangeSetPartlyArrived, holding: aReviewOfTheFirstFile)
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
        let model = await aLoadedViewerModel(of: aChangeSetPartlyArrived, holding: aReviewOfTheFirstFile)
        model.showReview()

        // when - then
        assertScreenSnapshot(screen(of: model), layout: layout, named: "the-review-is-open")
    }
}

// MARK: -

/// Wrapped the way the composition root wraps it, because a baseline of a screen out of its stack
/// asserts a toolbar nobody draws.
@MainActor
private func screen(of model: ClientViewerModel) -> some View {
    NavigationStack {
        WorktreeDiffScreen(worktreeName: "TLS pinning", model: model)
    }
}
