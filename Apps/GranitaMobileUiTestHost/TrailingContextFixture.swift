import SwiftUI
import UIKit

import ClientViewerPresentation
import CoreDiffDomain

@MainActor
struct TrailingContextFixture: View {

    @State private var model = ClientViewerModel(
        worktree: WorktreeID(rawValue: "trailing-context-worktree"),
        macName: "Fixture Mac",
        repository: FakeGranitaRepository(),
        commentStore: FakeReviewCommentStore(),
        pasteboard: FakeReviewPasteboard(),
        highlighter: FakeSyntaxHighlighter(),
        copyingLogs: FakeDiagnosticLogsCopying(answering: .success(())),
        announcing: FakeDiffReadAnnouncing(),
        onViewedCountChanged: { _, _ in },
        longWait: .seconds(60)
    )

    var body: some View {
        NavigationStack {
            WorktreeDiffScreen(worktreeName: "Trailing context", model: model, onPairAgain: {})
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ContextAnimationProbe().frame(height: 20)
                }
        }
        .preferredColorScheme(.light)
        .transaction { transaction in
            if ProcessInfo.processInfo.arguments.contains("disable-test-animations") {
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        }
    }
}

private struct ContextAnimationProbe: UIViewRepresentable {

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        label.isAccessibilityElement = true
        label.accessibilityIdentifier = "context-probe.animations"
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let value = "UIKit=\(UIView.areAnimationsEnabled);SwiftUI=\(context.transaction.disablesAnimations)"
        label.text = value
        label.accessibilityValue = value
    }
}
