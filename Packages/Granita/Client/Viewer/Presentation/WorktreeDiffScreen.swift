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
                    .presentationDetents([.medium, .large])
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
            .task { await model.load() }
    }

    @ViewBuilder private var content: some View {
        if showsSelectorAsAColumn {
            HStack(spacing: 0) {
                selector
                    .frame(width: FileSelectorView.widthBesideTheDiff)
                Divider()
                diff
            }
        } else {
            diff
        }
    }

    private var diff: some View {
        ContinuousDiffView(
            state: model.state,
            showsOldNumber: showsBothGutterColumns,
            jumpTarget: model.jumpTarget,
            onReading: { position in Task { await model.reading(position) } },
            onJumped: model.didJump,
            onSetViewed: { isViewed, file in Task { await model.setViewed(isViewed, on: file) } },
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
    @ToolbarContentBuilder private var filesButton: some ToolbarContent {
        if case .reading(let entries) = model.state, showsSelectorAsAColumn == false {
            ToolbarItem(placement: .primaryAction) {
                Button { model.showSelector(true) } label: {
                    Text(entries.count == 1 ? "1 file" : "\(entries.count, format: .number) files")
                }
            }
        }
    }

    /// Design §4's iPad: the selector column is permanently visible, so the drawer exists only on
    /// the phone.
    ///
    /// The question asked is the horizontal size class rather than the device, because an iPad in a
    /// narrow multitasking width is the phone's layout too — and a 320pt column taken out of 500 is
    /// the keyhole §4 rejected two number columns for being.
    private var showsSelectorAsAColumn: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    /// Design §4 keeps the new line number on the phone and both on iPad — 78pt of gutter against
    /// 39, which is the difference between 41 characters of code and 51.
    private var showsBothGutterColumns: Bool {
        showsSelectorAsAColumn
    }
}
