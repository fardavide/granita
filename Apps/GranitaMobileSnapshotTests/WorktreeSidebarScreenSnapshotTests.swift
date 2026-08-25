import ClientConnectionDomain
import ClientWorktreesDomain
import ClientWorktreesPresentation
import Foundation
import SwiftUI
import Testing

/// The screen rather than the view: the model bound to it, the sheet it presents and the alert its
/// two writes can raise.
///
/// The view's own suite covers what the rows look like. What only this one can reach is the
/// composition — the bindings a render reads, the sheet's presentation path, and the alert's — and
/// that is the same reason the Mac's Settings window is photographed with a folder scan in its
/// model rather than with an empty one.
///
/// **Two of these are named for what they show and not for what they exercise.** A hosted view
/// presents a sheet and an alert into windows of their own and the raster does not include them, so
/// a picture called `rename-sheet` would be a baseline asserting the opposite of its own name.
/// **Serialised, and it is the only suite here that needs to be.** Every other snapshot test runs
/// start to finish without suspending, so being main-actor isolated is enough to keep one render
/// away from another. These three await a load before they draw, and a suspension on the main actor
/// is where another rendering test can take the key window this one is about to photograph. A
/// rename-sheet baseline failed once in four runs on the branch that added them, and this is the one
/// thing the branch changed about how a raster is taken.
@Suite("Worktree sidebar screen composition", .serialized)
@MainActor
struct WorktreeSidebarScreenSnapshotTests {

    @Test(arguments: SnapshotLayout.all)
    func `given a loaded Mac when the screen is rendered then it matches its baseline`(
        layout: SnapshotLayout
    ) async {
        // given — loaded before rendering, so the raster is never a race between the screen's own
        // `.task` and the camera. The re-load the task performs answers the same way, so what is
        // photographed is settled rather than merely likely.
        let model = aModel()
        await model.load()

        // when - then
        assertScreenSnapshot(
            theSidebar(of: model, in: layout),
            layout: layout,
            named: "screen"
        )
    }

    @Test(arguments: SnapshotLayout.all)
    func `given the rename sheet is open when the screen is rendered then it matches its baseline`(
        layout: SnapshotLayout
    ) async throws {
        // given
        let model = aModel()
        await model.load()
        let subject = try #require(model.state.firstRow?.rename)
        model.beginRenaming(subject)

        // when - then
        assertScreenSnapshot(
            theSidebar(of: model, in: layout),
            layout: layout,
            named: "screen-beneath-the-rename-sheet"
        )
    }

    @Test(arguments: SnapshotLayout.all)
    func `given a write the Mac refused when the screen is rendered then it matches its baseline`(
        layout: SnapshotLayout
    ) async throws {
        // given — the row is left exactly as it was, which is what the alert exists to explain.
        let model = aModel(writeFailure: .unauthorized)
        await model.load()
        let row = try #require(model.state.firstRow)
        await model.setPinned(row.isPinned == false, on: row.id)

        // when - then
        assertScreenSnapshot(
            theSidebar(of: model, in: layout),
            layout: layout,
            named: "screen-beneath-the-refusal"
        )
    }
}

// MARK: -

/// The screen in the room the composition root gives it: on the iPad the 320pt column of §2's split
/// view, and on the phone the whole window.
///
/// The clamp is outside the navigation container, because iOS draws a title in the bar rather than
/// in the content and a measure applied inside would assert an alignment the app does not have.
/// Leading rather than centred, because that is the edge the column is against — what sits beside it
/// on a real iPad is the detail column, and that is the split screen's own suite.
@MainActor
private func theSidebar(of model: ClientWorktreesModel, in layout: SnapshotLayout) -> some View {
    NavigationStack { WorktreeSidebarScreen(model: model) }
        .frame(maxWidth: layout.isRegularWidth ? WorktreeSplitScreen.sidebarWidth : nil)
        .frame(maxWidth: .infinity, alignment: .leading)
}

@MainActor
private func aModel(writeFailure: ApiFailure? = nil) -> ClientWorktreesModel {
    ClientWorktreesModel(
        repository: FakeGranitaRepository(worktrees: aBusyMac, writeFailure: writeFailure),
        preferences: FakeWorktreeListPreferences(mode: .groupedByProject, showsQuiet: false),
        now: { aFixedMoment }
    )
}

private extension WorktreeSidebarState {

    /// The row a swipe would land on, which is the first one the reader can see.
    var firstRow: WorktreeListRow? {
        guard case .listing(let listing) = self else { return nil }
        return listing.sections.first?.rows.first
    }
}
