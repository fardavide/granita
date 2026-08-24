import SwiftUI

/// What selecting a worktree says, until the file selector has a screen.
///
/// **This exists because the alternative shipped once and was the worst defect this product has
/// had.** A row that looks operable must do something the reader can perceive; when what is behind
/// it is not built, it says so in this design's own empty-state idiom. Being mid-milestone is not an
/// exception — it is the case the rule is for.
///
/// It goes when design §3's file selector arrives, and it is deliberately not a stub: this is a real
/// state with real copy. No action, because there is nothing on this phone to tap.
public struct WorktreeNotReadyView: View {

    private let worktreeName: String

    public init(worktreeName: String) {
        self.worktreeName = worktreeName
    }

    public var body: some View {
        ContentUnavailableView {
            Label("The file list is not ready yet", systemImage: "doc.text.magnifyingglass")
        } description: {
            // Names the worktree, because the reader chose it and being told the app knows which one
            // is half of what makes this read as a state rather than as a failure.
            Text(
                """
                Granita knows what changed in \(worktreeName), but the screen that shows the files \
                and their diffs is still being built.
                """
            )
        }
        .navigationTitle(worktreeName)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
