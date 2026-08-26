import SwiftUI

import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain

/// Binds the viewer model to the one continuous scroll, and is where a chosen worktree lands.
///
/// The screen lives here rather than in `Ui` because it owns state, and owning state is what
/// separates the two layers: `Ui` renders what it is handed, `Presentation` decides what that is.
///
/// **It replaces `WorktreeNotReadyView`**, which said for two releases that this screen was not
/// built. That view was not a stub — it was a real state with real copy, which is what this project
/// requires of a control whose destination does not exist yet. It exists no longer because the
/// destination does.
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
        ContinuousDiffView(
            state: model.state,
            showsOldNumber: showsBothGutterColumns,
            onReading: { position in Task { await model.reading(position) } },
            onRetry: { Task { await model.load() } }
        )
        .navigationTitle(worktreeName)
        #if !os(macOS)
        // Inline for the same reason the worktree list's own title is: 34pt bold holds about
        // sixteen characters, and an agent's session summary is a sentence rather than a word.
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await model.load() }
    }

    /// Design §4 keeps the new line number on the phone and both on iPad — 78pt of gutter against
    /// 39, which is the difference between 41 characters of code and 51.
    ///
    /// The question asked is the horizontal size class rather than the device, because an iPad in a
    /// narrow multitasking width is the phone's layout too.
    private var showsBothGutterColumns: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }
}
