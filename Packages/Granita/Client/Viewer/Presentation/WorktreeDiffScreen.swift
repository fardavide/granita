import SwiftUI

import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain

/// Binds the viewer model to design §4's one continuous scroll and design §3's selector beside it,
/// and is where a chosen worktree lands.
///
/// The screen lives here rather than in `Ui` because it owns state, and owning state is what
/// separates the two layers: `Ui` renders what it is handed, `Presentation` decides what that is.
///
/// **It replaces `WorktreeNotReadyView`**, which said for two releases that this screen was not
/// built. That view was not a stub — it was a real state with real copy, which is what this project
/// requires of a control whose destination does not exist yet. It exists no longer because the
/// destination does.
///
/// **Two presentations of one list, which is design §3's own instruction.** On the phone the selector
/// is a drawer: a sheet at the medium and large detents with background interaction enabled up
/// through medium, so the diff keeps scrolling behind it and tapping a file jumps the scroll *with
/// the list still open* — the reader walks a change set file by file without a dismiss-present cycle
/// between each one. In a regular width it is permanently visible beside the code at 320pt, which is
/// §4's three columns at 320 / 320 / 554. The tree itself is the same view in both.
public struct WorktreeDiffScreen: View {

    @State private var model: ClientViewerModel

    /// **Open by default and shut by the reader**, which is the review's iPad and Davide's amendment
    /// to it on 1 September 2026: the tree is furniture rather than a modal, and a reader who wants
    /// the whole window for code can fold it away and get the phone's *Files* button back in its
    /// place. Nothing is lost by shutting it, which is what makes shutting it safe to offer.
    @State private var isSelectorColumnOpen = true

    private let worktreeName: String

    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    public init(worktreeName: String, model: ClientViewerModel) {
        self.worktreeName = worktreeName
        // Pinned in `@State` rather than held as a plain `let`, the same way every other screen in
        // this app does it and for the reason the iPad's split view proved: a destination closure is
        // re-evaluated, and a plain property would swap the displayed model while the running
        // `.task` kept driving the discarded one.
        _model = State(initialValue: model)
    }

    public var body: some View {
        content
            .navigationTitle(worktreeName)
            #if !os(macOS)
            // Inline for the same reason the worktree list's own title is: 34pt bold holds about
            // sixteen characters, and an agent's session summary is a sentence rather than a word.
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { selectorColumnToggle }
            .toolbar { filesButton }
            // The setter is written out rather than handed `model.showSelector`, which is the
            // repository's IRGen crash arriving from a new direction: a method reference in a
            // `Binding`'s setter makes swiftc emit a reabstraction thunk and abort with
            // `SmallVector unable to grow`. A closure that calls the same method compiles.
            .sheet(isPresented: Binding(get: { model.isShowingSelector }, set: { model.showSelector($0) })) {
                // `.presentationBackgroundInteraction` is the one modifier that turns a modal into a
                // drawer: with it the diff keeps scrolling behind the sheet and the dimming goes,
                // which is what makes tapping a file *while the list is open* a different tool from
                // a modal that has to be dismissed between every file.
                selector
                    // **The detent is a value the model holds rather than one the sheet keeps to
                    // itself**, because choosing a file has to be able to move it: at `.large` the
                    // diff behind the sheet is not on screen and background interaction is off, so
                    // the jump the tap asked for lands where nobody can see it. `choose` drops this
                    // back to `.medium`, and the reader's own drag writes it the other way.
                    //
                    // **Projected rather than hand-built**, which is the difference between a rule a
                    // test can drive and one it cannot: a `Binding(get:set:)` here would put "which
                    // height means what" inside two closures that no baseline renders and no host
                    // test reaches. `drawerDetent` is on the model, and this is the framework's own
                    // projection of it — which also avoids the `Binding` setter shape the
                    // presentation flag above documents a compiler crash for.
                    .presentationDetents([.medium, .large], selection: $model.drawerDetent)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .alert(
                "Your Mac would not make that change",
                isPresented: Binding(
                    get: { model.viewedFailure != nil },
                    set: { if $0 == false { model.dismissViewedFailure() } }
                )
            ) {
                Button("OK") { model.dismissViewedFailure() }
            } message: {
                // The mark went back to what it was, so without this the toggle is a control that
                // appears to have done nothing — twice, since it moved and then moved back.
                Text("The file is still marked as it was. Trying again usually works.")
            }
            // A second refusal with a sentence of its own rather than one alert covering both. They
            // are different promises: a mark that moved and came back needs the reader told it came
            // back, and an expansion that was refused left the hunk exactly as it was.
            .alert(
                "Your Mac would not send those lines",
                isPresented: Binding(
                    get: { model.expansionFailure != nil },
                    set: { if $0 == false { model.dismissExpansionFailure() } }
                )
            ) {
                Button("OK") { model.dismissExpansionFailure() }
            } message: {
                Text("Nothing was added to the diff. Trying again usually works.")
            }
            .task { await model.load() }
    }

    @ViewBuilder private var content: some View {
        HStack(spacing: 0) {
            if layout.showsSelectorColumn {
                selector
                    .frame(width: FileSelectorView.widthBesideTheDiff)
                    // The column leaving and arriving is a layout change the reader pressed for, so
                    // it moves rather than teleports — the same curve every other disclosure on this
                    // screen uses.
                    .transition(.move(edge: .leading))
                Divider()
                    .transition(.opacity)
            }
            diff
        }
        // On the container that lays out the movement, which is what 0.5.2 got wrong inside a file
        // and is the same rule here: the thing that travels when the column goes is the diff beside
        // it, and the diff's position belongs to this stack.
        .animation(.disclosure, value: layout.showsSelectorColumn)
    }

    private var diff: some View {
        ContinuousDiffView(
            state: model.state,
            pointSize: layout.codePointSize,
            jumpTarget: model.jumpTarget,
            onReading: { position in Task { await model.reading(position) } },
            onJumped: model.didJump,
            onSetViewed: { isViewed, file in Task { await model.setViewed(isViewed, on: file) } },
            onSetOpen: { isOpen, file in Task { await model.setOpen(isOpen, on: file) } },
            onExpand: { way, hunk, file in Task { await model.expand(way, hunk: hunk, in: file) } },
            onRetry: { Task { await model.load() } }
        )
    }

    private var selector: some View {
        FileSelectorView(
            listing: model.selector,
            onChoose: model.choose,
            onToggleDirectory: model.toggle,
            onChooseMode: model.show
        )
    }

    /// The way to the drawer, and the count design §3's frame puts on it — *12 files* rather than a
    /// glyph, because it is also the only place the phone says how big the read is before the reader
    /// starts scrolling.
    ///
    /// **Absent while there is nothing to select**, which is every state but one: a button opening a
    /// drawer over a worktree that failed to load, or has nothing changed in it, would open an empty
    /// list and say nothing about why.
    ///
    /// **It comes back when the iPad's column is folded away.** A width that could show the tree but
    /// currently is not is the phone's situation exactly, and leaving the reader with no way to the
    /// list would make the fold control a one-way door.
    @ToolbarContentBuilder private var filesButton: some ToolbarContent {
        if case .reading(let entries) = model.state, layout.showsFilesButton {
            ToolbarItem(placement: .primaryAction) {
                Button { model.showSelector(true) } label: {
                    Text(entries.count == 1 ? "1 file" : "\(entries.count, format: .number) files")
                }
            }
        }
    }

    /// **The fold, and it is a plain icon rather than a labelled control.** The review's own note on
    /// the iPad bar is that mixing an icon and text in one element makes two controls read as one, so
    /// this stands apart from the back button and says nothing.
    ///
    /// Only where a column would fit: on the phone there is no column to fold, and a toggle for a
    /// layout that does not exist is the dead control this project refuses to ship.
    @ToolbarContentBuilder private var selectorColumnToggle: some ToolbarContent {
        if layout.showsSelectorColumnToggle {
            ToolbarItem(placement: .navigation) {
                Button {
                    isSelectorColumnOpen.toggle()
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .accessibilityLabel(isSelectorColumnOpen ? "Hide the file list" : "Show the file list")
            }
        }
    }

    /// Every layout answer this screen needs, decided in one place a test can reach.
    ///
    /// The horizontal size class rather than the device, because an iPad in a narrow multitasking
    /// width is the phone's layout too — and a 320pt column taken out of 500 is the keyhole design
    /// §4 rejected two number columns for being.
    private var layout: DiffPaneLayout {
        #if os(macOS)
        let fits = true
        #else
        let fits = horizontalSizeClass == .regular
        #endif
        return DiffPaneLayout(
            fitsSelectorColumn: fits,
            isSelectorColumnOpen: isSelectorColumnOpen,
            hasFilesToSelect: hasFilesToSelect
        )
    }

    private var hasFilesToSelect: Bool {
        if case .reading = model.state { true } else { false }
    }
}
