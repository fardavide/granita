import ClientWorktreesUi
import SwiftUI
import Testing

/// What a reader is told when they select a worktree, until design §3's file selector is built.
///
/// It has a baseline because it is a real state with real copy rather than a stub — the point of it
/// is that the row does something perceivable, and that is a thing worth photographing.
@Suite("Worktree not ready screen")
@MainActor
struct WorktreeNotReadyViewSnapshotTests {

    @Test(arguments: SnapshotLayout.all)
    func `given a selected worktree when rendering then it matches its baseline`(layout: SnapshotLayout) {
        // given - when - then
        assertScreenSnapshot(
            NavigationStack {
                WorktreeNotReadyView(worktreeName: "Make the diff scroll never reflow above the reader's finger")
            },
            layout: layout,
            named: "not-ready"
        )
    }
}
