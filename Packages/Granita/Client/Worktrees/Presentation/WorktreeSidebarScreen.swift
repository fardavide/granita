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
/// **The whole screen, and on the iPad only one column of it.** Pairing routes here, so it is
/// reached two ways: directly from the stack in a compact width, and as the sidebar of `§2`'s split
/// view otherwise — which is why the destination below is declared here *and* on the containers
/// `WorktreeSplitScreen` owns. A split view keeps what its columns declare, and a row whose
/// destination is kept from the container that receives it is a row that does nothing, which is the
/// defect this project shipped for eight releases.
///
/// **What a row opens is handed in rather than built here**, and that is the layer graph rather than
/// a preference: the diff screen is another feature's `Presentation`, and a `Presentation` target
/// may see its own feature's `Ui` and any `Domain` — never a sibling `Presentation`. The declaration
/// stays inside this module, where the container that claims the tap can reach it, and only what it
/// builds comes from the composition root. **It is a required parameter**, so a row that leads
/// nowhere does not compile — which is a stronger guarantee than the comment this project relied on
/// for the eight releases it shipped one.
///
/// **The name goes with the identifier, and that is a defect this repository has already had once.**
/// The builder is written in the composition root, whose `navigationDestination` closure is
/// re-evaluated and builds a *new* worktrees model every time — while this screen pins the first one
/// and is the only thing that loads it. A builder that resolved the name itself would resolve it
/// against whichever instance the last evaluation produced, one that has read nothing, and every
/// worktree would open titled *This worktree*. That is 0.1.0's iPad defect exactly, and passing the
/// resolved name is what stops it coming back through the door built to keep a row from going
/// quiet.
public struct WorktreeSidebarScreen<Opened: View>: View {

    @State private var model: ClientWorktreesModel

    private let opening: (WorktreeID, String) -> Opened

    public init(
        model: ClientWorktreesModel,
        @ViewBuilder opening: @escaping (WorktreeID, _ displayName: String) -> Opened
    ) {
        // Pinned in @State rather than held as a plain `let`, for the same reason discovery's screen
        // does it: the composition root rebuilds this on every parent re-evaluation, and a plain
        // property would swap the displayed model while the running .task kept driving the discarded
        // one.
        _model = State(initialValue: model)
        self.opening = opening
    }

    public var body: some View {
        WorktreeSidebarView(
            macName: model.macName,
            state: model.state,
            mode: model.mode,
            showsQuietWorktrees: model.showsQuietWorktrees,
            removing: model.removing,
            onChooseMode: model.show,
            onShowQuietWorktrees: model.showQuietWorktrees,
            onRename: model.beginRenaming,
            onSetPinned: { pinned, worktree in
                Task { await model.setPinned(pinned, on: worktree) }
            },
            onDelete: model.beginDeleting,
            onRetry: { Task { await model.load() } }
        )
        // **Declared beside the rows that link to it**, which is the placement that stops a link and
        // its destination drifting apart in two modules — the exact way this app came to ship a row
        // that did nothing at all. See `CLAUDE.md` and `.claude/docs/decisions.md`.
        .navigationDestination(for: WorktreeID.self) { worktree in
            opening(worktree, model.displayName(of: worktree))
        }
        .sheet(item: Binding(get: { model.renaming }, set: { if $0 == nil { model.cancelRenaming() } })) { subject in
            WorktreeRenameSheet(
                subject: subject,
                onSave: { alias in Task { await model.rename(subject.worktree, to: alias) } },
                onCancel: model.cancelRenaming
            )
        }
        // **One alert driven by a two-case prompt, rather than one modifier each.** Two `.alert`
        // modifiers on a single view is the shape where only one ever presents, and the one that
        // would lose is the confirmation in front of the only control here that destroys anything.
        .alert(
            prompt.title,
            isPresented: Binding(
                get: { prompt != nil },
                set: { if $0 == false { model.dismissPrompt() } }
            ),
            presenting: prompt
        ) { prompt in
            switch prompt {
            case .confirmDeletion(let subject):
                // The subject travels with the button rather than being read back off the model.
                // The line above clears `model.deleting` synchronously as this alert dismisses,
                // while this `Task` body runs a turn later — so a version that looked the subject up
                // would find nothing and destroy nothing, silently.
                Button("Delete Worktree", role: .destructive) {
                    Task { await model.confirmDeletion(of: subject) }
                }
                Button("Cancel", role: .cancel) { model.cancelDeleting() }
            case .refusal:
                Button("OK") { model.dismissWriteFailure() }
            }
        } message: { prompt in
            Text(prompt.message)
        }
        .task { await model.load() }
    }

    /// What the alert is currently for, or nothing.
    ///
    /// A refusal wins where both are set, because it is the later event and it is about something
    /// that has already happened. In practice they cannot coexist — `confirmDeletion(of:)` clears
    /// the subject before it awaits — and stating the order is cheaper than relying on that.
    ///
    /// **What it says lives beside it rather than in this body**, in `WorktreeDeletionCopy`: an
    /// alert is presented into a window of its own and no raster here includes it, so a sentence
    /// written in a screen is a sentence nothing in this repository can hold to its words. These are
    /// the words a reader gets at the worst moment this app has.
    private var prompt: WorktreeAlertPrompt? {
        if let refusal = model.writeFailure { return .refusal(refusal) }
        if let subject = model.deleting { return .confirmDeletion(subject) }
        return nil
    }
}
