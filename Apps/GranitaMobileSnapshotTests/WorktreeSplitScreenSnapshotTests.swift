import ClientWorktreesDomain
import ClientViewerPresentation
import ClientWorktreesPresentation
import CoreDiffDomain
import Foundation
import SwiftUI
import Testing

/// Design §2's iPad half: the list as a 320pt sidebar, beside the column that says what to do with
/// it.
///
/// **This is the only suite that photographs the two columns.** The sidebar's own two suites now
/// take the width from here, so all three agree about how much room the row has — 390 on the phone
/// and 320 on the iPad — and what they assert is the row while what this asserts is the room it is
/// in. The same render on the phone is the other half of the point: a split view in a compact width
/// collapses to its sidebar, and the baseline is what proves the iPad's shape costs the phone
/// nothing.
///
/// Rendered inside a `NavigationStack`, because that is where the composition root puts it and
/// because a split view nested in a stack is the one part of this composition no unit test can have
/// an opinion about.
///
/// **Serialised**, for the reason the sidebar screen's suite is: these await a load before they draw,
/// and a suspension on the main actor is where another rendering test can take the key window this
/// one is about to photograph.
@Suite("Worktree split screen", .serialized)
@MainActor
struct WorktreeSplitScreenSnapshotTests {

    @Test(arguments: SnapshotLayout.all)
    func `given a loaded Mac when the split screen is rendered then it matches its baseline`(
        layout: SnapshotLayout
    ) async {
        // given — loaded before rendering, so the raster is settled rather than a race between the
        // screen's own `.task` and the shutter.
        let model = aLoadableModel()
        await model.load()
        let diff = await aLoadedViewerModel()

        // when - then
        assertScreenSnapshot(
            NavigationStack {
                WorktreeSplitScreen(model: model) { worktree in
                    WorktreeDiffScreen(worktreeName: model.displayName(of: worktree), model: diff)
                }
            },
            layout: layout,
            named: "split"
        )
    }

    /// **The one thing a picture of the resting screen cannot say: that a chosen row still leads
    /// somewhere.**
    ///
    /// A row is a value-based link, and a value-based link is silent when nothing declares a
    /// destination for its value — which is how this app once shipped a list nobody could open. So
    /// the worktree goes on the stack the composition root owns, and what comes back is whatever
    /// the tap would have drawn.
    ///
    /// **This is the test that found the hole.** Written against the first build of this screen, it
    /// came back on iPad as the system's yellow missing-destination placeholder: a split view keeps
    /// the destinations declared inside its columns to itself, so the one the sidebar has declared
    /// since it was written no longer reaches the stack around it. The screen now declares that
    /// destination on both containers, and this is the half of the pair a baseline can reach.
    ///
    /// What it still cannot say is which container a *tap* hands the value to, because no test kind
    /// that runs here can tap. Both lead to this screen, which is what makes that survivable.
    @Test(arguments: SnapshotLayout.all)
    func `given a worktree was chosen when the split screen is rendered then its screen is reached`(
        layout: SnapshotLayout
    ) async throws {
        // given
        let model = aLoadableModel()
        await model.load()
        let diff = await aLoadedViewerModel()
        let chosen = try #require(aBusyMac.first).id

        // when - then
        assertScreenSnapshot(
            NavigationStack(path: .constant(NavigationPath([chosen]))) {
                WorktreeSplitScreen(model: model) { worktree in
                    WorktreeDiffScreen(worktreeName: model.displayName(of: worktree), model: diff)
                }
            },
            layout: layout,
            named: "split-with-a-worktree-chosen"
        )
    }

    /// **The word that appears when the screen and its destination are not reading the same list.**
    ///
    /// `displayName(of:)` falls back to *This worktree* whenever the chosen row is not in the state
    /// the model is holding, which is legitimately true for exactly one thing: an agent removes a
    /// checkout every day, so one can stop being in the list between the tap and the push. It was
    /// also, for a release, true of every tap on an iPad — the destination was resolving names
    /// against a model the composition root had just rebuilt and nothing had loaded, so this word
    /// was the title of every worktree there was.
    ///
    /// Photographed so that it is a state somebody chose rather than one nobody could see. What a
    /// picture still cannot say is which *instance* a screen is holding, so the fix for that is
    /// structural — the model is pinned — and this is the half that has a baseline.
    @Test(arguments: SnapshotLayout.all)
    func `given a worktree that is no longer listed when the split screen is rendered then it says so plainly`(
        layout: SnapshotLayout
    ) async {
        // given — a row read, tapped, and gone from the Mac by the time the push happened.
        let model = aLoadableModel()
        await model.load()
        let diff = await aLoadedViewerModel()
        let removed = WorktreeID(rawValue: "w-an-agent-deleted-this-one")

        // when - then
        assertScreenSnapshot(
            NavigationStack(path: .constant(NavigationPath([removed]))) {
                WorktreeSplitScreen(model: model) { worktree in
                    WorktreeDiffScreen(worktreeName: model.displayName(of: worktree), model: diff)
                }
            },
            layout: layout,
            named: "split-with-a-worktree-that-is-gone"
        )
    }
}

// MARK: -

@MainActor
private func aLoadableModel() -> ClientWorktreesModel {
    ClientWorktreesModel(
        macName: aMacName,
        repository: FakeGranitaRepository(worktrees: aBusyMac, writeFailure: nil),
        preferences: FakeWorktreeListPreferences(mode: .groupedByProject, showsQuiet: false),
        now: { aFixedMoment }
    )
}
