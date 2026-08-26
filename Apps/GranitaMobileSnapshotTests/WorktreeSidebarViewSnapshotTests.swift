import ClientConnectionDomain
import ClientWorktreesDomain
import ClientWorktreesPresentation
import ClientWorktreesUi
import CoreDiffDomain
import Foundation
import SwiftUI
import Testing

/// Every state the worktree sidebar can be in, in every layout it has to survive.
///
/// This is what `WorktreeSidebarView` taking its state as a value buys: three of these are a
/// paired Mac behaving in a particular way, and here they are all just values.
///
/// Main-actor isolated, and it must be. Swift Testing runs `@Test` functions off the main actor by
/// default, and rendering touches UIKit view properties — which trap with
/// `_raiseExceptionForBackgroundThreadLayerPropertyModification`. That trap is worse than a plain
/// failure: the crash restarts the test host, and the retry then reports "0 tests passed", so the
/// suite goes green having rendered nothing.
@Suite("Worktree sidebar screen")
@MainActor
struct WorktreeSidebarViewSnapshotTests {

    @Test(arguments: SidebarCase.all, SnapshotLayout.all)
    func `given a sidebar state when rendering then it matches its baseline`(
        subject: SidebarCase,
        layout: SnapshotLayout
    ) {
        // given - when - then
        //
        // Wrapped in a NavigationStack because `.navigationTitle` and `.toolbar` render nothing
        // outside a navigation container — an unwrapped baseline would silently stop covering both
        // the title and the one control this screen puts in the bar.
        //
        // No 420pt measure, unlike design §1's screens: that clamp is for the pre-pairing screens.
        // **This one is §2's own**, and it is not a measure at all but the width the split view gives
        // the sidebar — 320, which is narrower than the phone's 390, so the iPad is the harder layout
        // for this row rather than the easier one. Until the root that builds that split view existed
        // these baselines were taken across the whole 1,194pt: a width the row has on no device, and
        // the one where §2's drop order never has to do anything.
        assertScreenSnapshot(
            NavigationStack {
                WorktreeSidebarView(
                    macName: subject.macName,
                    state: subject.state,
                    mode: subject.mode,
                    showsQuietWorktrees: subject.showsQuietWorktrees,
                    onChooseMode: { _ in },
                    onShowQuietWorktrees: { _ in },
                    onRename: { _ in },
                    onSetPinned: { _, _ in },
                    onRetry: {}
                )
            }
            .frame(maxWidth: layout.isRegularWidth ? WorktreeSidebarView.widthInASplitView : nil)
            // Leading rather than centred, because that is the edge the column is against. What is
            // beside it on a real iPad is the detail column, which is the split screen's own suite.
            .frame(maxWidth: .infinity, alignment: .leading),
            layout: layout,
            named: subject.name
        )
    }
}

// MARK: -

/// Named so the baseline filename says which state it captures, and so a failure names it too.
struct SidebarCase: Sendable, CustomTestStringConvertible {

    let name: String
    let macName: String
    let state: WorktreeSidebarState
    let mode: WorktreeListMode
    let showsQuietWorktrees: Bool

    var testDescription: String { name }

    /// The Mac's name is the same in every case but one, so it is defaulted here rather than
    /// repeated ten times: what each of these varies is the state, and a field spelled identically
    /// on every line reads as noise until the one line that changes it.
    init(
        name: String,
        macName: String = aMacName,
        state: WorktreeSidebarState,
        mode: WorktreeListMode,
        showsQuietWorktrees: Bool
    ) {
        self.name = name
        self.macName = macName
        self.state = state
        self.mode = mode
        self.showsQuietWorktrees = showsQuietWorktrees
    }

    static let all: [SidebarCase] = [
        // The list as design §2 draws it: one Pinned section above the projects, a pinned row
        // carrying the project name no other grouped row does, a machine-generated name that has to
        // read as a machine string, and the footer that says what is being hidden.
        SidebarCase(
            name: "grouped",
            state: .listing(WorktreeListing(of: aBusyMac, mode: .groupedByProject, showingQuiet: false, now: aFixedMoment)),
            mode: .groupedByProject,
            showsQuietWorktrees: false
        ),

        // The same worktrees, flat: every row promotes its project name and the pin becomes a glyph,
        // because there is no header left to carry it.
        SidebarCase(
            name: "flat",
            state: .listing(WorktreeListing(of: aBusyMac, mode: .mostRecentFirst, showingQuiet: false, now: aFixedMoment)),
            mode: .mostRecentFirst,
            showsQuietWorktrees: false
        ),

        // With the quiet ones shown: the primary checkout that earns a word, the unborn head that
        // takes the stats slot rather than lying with the whole repository's figures, and no footer,
        // because nothing is being hidden.
        SidebarCase(
            name: "quiet-shown",
            state: .listing(WorktreeListing(of: aBusyMac, mode: .groupedByProject, showingQuiet: true, now: aFixedMoment)),
            mode: .groupedByProject,
            showsQuietWorktrees: true
        ),

        // One hidden worktree rather than several, which is a sentence of its own rather than the
        // same one with a 1 in it.
        SidebarCase(
            name: "one-hidden",
            state: .listing(
                WorktreeListing(of: aQuietOneAmongFour, mode: .mostRecentFirst, showingQuiet: false, now: aFixedMoment)
            ),
            mode: .mostRecentFirst,
            showsQuietWorktrees: false
        ),

        // Nothing on this phone to tap, on purpose: the description names the exact menu on the Mac,
        // so the sentence is the instruction.
        SidebarCase(name: "no-projects", state: .noProjects, mode: .groupedByProject, showsQuietWorktrees: false),

        SidebarCase(
            name: "all-quiet",
            state: .allQuiet(worktreeCount: 9, projectNames: ["aura", "granita"]),
            mode: .groupedByProject,
            showsQuietWorktrees: false
        ),

        // One worktree in one project. "All 1 worktrees across granita" is what the other sentence
        // would have produced.
        SidebarCase(
            name: "all-quiet-alone",
            state: .allQuiet(worktreeCount: 1, projectNames: ["granita"]),
            mode: .groupedByProject,
            showsQuietWorktrees: false
        ),

        // The machine's own words in small print under our sentence, which is where a diagnostic
        // goes on every screen in this app.
        SidebarCase(
            name: "failed",
            state: .failed(.unreachable(diagnostic: "The operation couldn’t be completed.\nNWError -65563")),
            mode: .groupedByProject,
            showsQuietWorktrees: false
        ),

        // A refusal the Mac spells deliberately, which carries no small print at all — the state
        // that would otherwise leave an empty caption slot nobody had photographed.
        SidebarCase(
            name: "failed-plainly",
            state: .failed(.unauthorized),
            mode: .groupedByProject,
            showsQuietWorktrees: false
        ),

        // A request that has neither answered nor failed. Unlike a Bonjour browse this one finishes,
        // so a progress view is not a promise this screen cannot keep.
        SidebarCase(name: "loading", state: .loading, mode: .groupedByProject, showsQuietWorktrees: false),

        // A Mac called what Macs are actually called. The title is the reader's only answer to
        // "which machine am I reading", so what it does when the name is longer than the column is
        // a state somebody has to have looked at rather than one nobody photographed — and the
        // iPad's 320pt sidebar is narrower than the phone, so it is the harder of the two.
        SidebarCase(
            name: "long-mac-name",
            macName: "Davide's 16-inch MacBook Pro",
            state: .listing(WorktreeListing(of: aBusyMac, mode: .groupedByProject, showingQuiet: false, now: aFixedMoment)),
            mode: .groupedByProject,
            showsQuietWorktrees: false
        )
    ]
}

// MARK: -

/// Three with changes and exactly one without, which is the singular half of the footer's sentence.
private nonisolated let aQuietOneAmongFour: [Worktree] = Array(aBusyMac.prefix(3)) + [aBusyMac[5]]
