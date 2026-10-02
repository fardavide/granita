import SwiftUI

import CoreComponentsUi

public struct WorktreeGoneView: View {
    private let name: String

    public init(name: String) {
        self.name = name
    }

    public var body: some View {
        EmptyState {
            Label("This worktree is gone", systemImage: "folder.badge.questionmark")
        } description: {
            Text("\(name) is no longer on this Mac. Choose another worktree in the sidebar.")
        }
    }
}
