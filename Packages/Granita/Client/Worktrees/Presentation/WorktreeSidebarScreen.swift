import SwiftUI

import ClientWorktreesDomain
import ClientWorktreesUi
import CoreDiffDomain

/// Binds the worktrees model to the sidebar, its rename sheet and the refusals its two writes can
/// come back with.
///
/// The screen lives here rather than in `Ui` because it owns state, and owning state is what
/// separates the two layers: `Ui` renders what it is handed, `Presentation` decides what that is.
///
/// **The whole screen, and on the iPad only one column of it.** Pairing routes here now, so it is
/// reached two ways: directly from the stack in a compact width, and as the sidebar of `§2`'s split
/// view otherwise — which is why the destination below is declared here *and* on the containers
/// `WorktreeSplitScreen` owns. A split view keeps what its columns declare, and a row whose
/// destination is kept from the container that receives it is a row that does nothing, which is the
/// defect this project shipped for eight releases.
public struct WorktreeSidebarScreen: View {

    @State private var model: ClientWorktreesModel

    public init(model: ClientWorktreesModel) {
        // Pinned in @State rather than held as a plain `let`, for the same reason discovery's screen
        // does it: the composition root rebuilds this on every parent re-evaluation, and a plain
        // property would swap the displayed model while the running .task kept driving the discarded
        // one.
        _model = State(initialValue: model)
    }

    public var body: some View {
        WorktreeSidebarView(
            macName: model.macName,
            state: model.state,
            mode: model.mode,
            showsQuietWorktrees: model.showsQuietWorktrees,
            onChooseMode: model.show,
            onShowQuietWorktrees: model.showQuietWorktrees,
            onRename: model.beginRenaming,
            onSetPinned: { pinned, worktree in
                Task { await model.setPinned(pinned, on: worktree) }
            },
            onRetry: { Task { await model.load() } }
        )
        // **Declared beside the rows that link to it**, which is the placement that stops a link and
        // its destination drifting apart in two modules — the exact way this app came to ship a row
        // that did nothing at all. See `CLAUDE.md` and `.claude/docs/decisions.md`.
        .navigationDestination(for: WorktreeID.self) { worktree in
            WorktreeNotReadyView(worktreeName: model.displayName(of: worktree))
        }
        .sheet(item: Binding(get: { model.renaming }, set: { if $0 == nil { model.cancelRenaming() } })) { subject in
            WorktreeRenameSheet(
                subject: subject,
                onSave: { alias in Task { await model.rename(subject.worktree, to: alias) } },
                onCancel: model.cancelRenaming
            )
        }
        .alert(
            "Your Mac would not make that change",
            isPresented: Binding(
                get: { model.writeFailure != nil },
                set: { if $0 == false { model.dismissWriteFailure() } }
            )
        ) {
            Button("OK") { model.dismissWriteFailure() }
        } message: {
            // Renaming and pinning both leave the row exactly where it was when they fail, so
            // without this the swipe is a control that appears to have done nothing.
            Text("The row is still as it was. Trying again usually works.")
        }
        .task { await model.load() }
    }
}
