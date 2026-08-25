import SwiftUI

import ClientWorktreesUi
import CoreDiffDomain

/// Design §2's iPad shape for the list this product exists for: a 320pt sidebar, and a detail
/// column that says what to do with it.
///
/// **A screen rather than four lines in the composition root**, and the reason is the reason a
/// `Main` module is exempt from both coverage rows: what is left in one is untested code that no
/// longer looks untested. A split view with an empty state inside it is a screen — it can be
/// photographed, and it is. The root keeps the part that is genuinely wiring: that a paired Mac
/// lands here, over a repository pinned to that Mac.
///
/// **The compact width is branched rather than collapsed, and that was measured.** A split view is
/// documented to fold into its sidebar when the width is compact, so the first build of this screen
/// simply let it — and the iPhone baseline came back with the title, the toolbar menu and *no rows
/// at all*. A collapsed split view inside a navigation stack draws its chrome and none of its
/// content, and this screen is inside one because §5 requires that back returns to the Mac list. So
/// the phone gets the sidebar directly, which is what the collapse was supposed to produce, and
/// both halves are photographed.
public struct WorktreeSplitScreen: View {

    /// §2's measure for the sidebar, and it is *narrower* than the phone's 390: "the iPad is the
    /// harder layout for this row, not the easier one, and the drop order above is what saves it."
    ///
    /// Pinned rather than inherited from whatever the system hands a sidebar, so the arithmetic §2
    /// works the row's drop order out against is the arithmetic the baselines assert.
    ///
    /// Public because the row's own suites record against it: they photograph the list rather than
    /// the screen around it, and until this number reached them they photographed it across the
    /// whole 1,194pt — a width the row has on no device, and the one where §2's drop order never
    /// has to do anything.
    public static let sidebarWidth: CGFloat = 320

    @State private var model: ClientWorktreesModel

    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    public init(model: ClientWorktreesModel) {
        // **Pinned in `@State`, and here that is a fix rather than a precaution.** The composition
        // root presents this screen from inside a `navigationDestination` closure, so every
        // re-evaluation of that closure builds a **brand new model that has read nothing** — while
        // the sidebar below has pinned the first one and is the only thing loading it. Held as a
        // plain property, the two destinations declared below would then resolve a chosen row's
        // name against an empty list and open a screen titled *This worktree*, under a sidebar
        // showing the row that was tapped. Pinning is what makes the rows and their destination one
        // model. The sidebar and the discovery screen pin for the milder version of the same
        // reason.
        _model = State(initialValue: model)
    }

    public var body: some View {
        #if os(macOS)
        // The package builds for the host so `make test` can run without a simulator, and no macOS
        // surface presents this screen — `horizontalSizeClass` does not exist on that platform at
        // all, so there is nothing to branch on there.
        twoColumns
        #else
        // Compact is the phone, and it is also an iPad in a narrow multitasking width — which is why
        // the question asked is the width and not the device.
        if horizontalSizeClass == .compact {
            WorktreeSidebarScreen(model: model)
        } else {
            twoColumns
        }
        #endif
    }

    private var twoColumns: some View {
        NavigationSplitView {
            WorktreeSidebarScreen(model: model)
                .navigationSplitViewColumnWidth(Self.sidebarWidth)
        } detail: {
            // **A stack, not the empty state on its own, because the column a chosen row lands in
            // has to be able to hold it.** A split view claims the destinations declared inside its
            // columns rather than passing them out to the stack around it — photographed, not
            // assumed: a worktree put on the outer stack's path came back as the system's
            // missing-destination placeholder. So the destination is declared where the row's
            // value is meant to arrive.
            NavigationStack {
                NoWorktreeChosenView()
                    .openingTheChosenWorktree(of: model)
            }
        }
        // **And again on the stack around the split view, which is not superstition.** Two
        // containers can claim a row's value here — the split view, which routes a sidebar link
        // into the column after the one it was tapped in, and the stack the composition root owns,
        // which is what the split view is inside — and which of them takes it cannot be settled on
        // a machine with no finger. A baseline can reach the second, so the second is asserted and
        // the first is declared. Whichever claims it, the row opens the same screen; the one thing
        // that cannot happen is the row going quiet, which is the defect this app shipped for eight
        // releases. It collapses to one declaration the day §3's file selector gives the detail
        // column something of its own to show.
        .openingTheChosenWorktree(of: model)
    }
}

// MARK: -

private extension View {

    /// The one screen a chosen row leads to, written once and declared on both containers above so
    /// that they cannot answer the same tap with two different screens — or, as this app has
    /// managed before, with none.
    func openingTheChosenWorktree(of model: ClientWorktreesModel) -> some View {
        navigationDestination(for: WorktreeID.self) { worktree in
            WorktreeNotReadyView(worktreeName: model.displayName(of: worktree))
        }
    }
}
