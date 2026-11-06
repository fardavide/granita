import SwiftUI

import ClientMacDomain
import ClientViewerPresentation
import ClientWorktreesDomain
import ClientWorktreesPresentation
import CoreDiffDomain

@MainActor
struct LiveWorktreeFixture: View {
    @State private var repository: FakeGranitaRepository
    @State private var model: ClientViewerModel
    private let reviewed: WorktreeID
    private let other: WorktreeID

    init() {
        let reviewed = WorktreeID(rawValue: "reviewed-worktree")
        let other = WorktreeID(rawValue: "other-worktree")
        let repository = FakeGranitaRepository(liveWorktrees: [reviewed, other])
        self.reviewed = reviewed
        self.other = other
        _repository = State(initialValue: repository)
        _model = State(initialValue: ClientViewerModel(
            worktree: reviewed, macName: "Fixture Mac", repository: repository,
            commentStore: FakeReviewCommentStore(), pasteboard: FakeReviewPasteboard(),
            highlighter: FakeSyntaxHighlighter(), copyingLogs: FakeDiagnosticLogsCopying(answering: .success(())),
            announcing: FakeDiffReadAnnouncing(), onViewedCountChanged: { _, _ in }, longWait: .seconds(60)
        ))
    }

    var body: some View {
        NavigationStack {
            WorktreeDiffScreen(worktreeName: "Live review", model: model, onPairAgain: {})
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Change A") { repository.change(reviewed) }
                            .accessibilityLabel("Change this worktree")
                        Button("Change B") { repository.change(other) }
                            .accessibilityLabel("Change other worktree")
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack {
                        Text("Review reads")
                            .accessibilityIdentifier("live-probe.reads")
                            .accessibilityValue(String(repository.readCount(in: reviewed)))
                        Text("Other revision")
                            .accessibilityIdentifier("live-probe.otherRevision")
                            .accessibilityValue(String(repository.revision(in: other)))
                        ContextAnimationProbe().frame(height: 20)
                    }
                    .font(.caption)
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

@MainActor
struct LiveWorktreeSidebarFixture: View {
    @State private var repository: FakeGranitaRepository
    @State private var sidebar: ClientWorktreesModel
    @State private var selection: ReaderWorktreeSelection
    private let reviewed: WorktreeID
    private let other: WorktreeID

    init() {
        let reviewed = WorktreeID(rawValue: "reviewed-worktree")
        let other = WorktreeID(rawValue: "other-worktree")
        let repository = FakeGranitaRepository(liveWorktrees: [reviewed, other])
        self.reviewed = reviewed
        self.other = other
        _selection = State(initialValue: .chosen(reviewed, name: "Review A"))
        _repository = State(initialValue: repository)
        _sidebar = State(initialValue: ClientWorktreesModel(
            macName: "Fixture Mac", repository: repository,
            preferences: LiveWorktreePreferences(),
            copyingLogs: FakeDiagnosticLogsCopying(answering: .success(())),
            announcing: LiveWorktreeAnnouncements(),
            now: { Date(timeIntervalSince1970: 1_000) }
        ))
    }

    var body: some View {
        worktrees
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Change this worktree") { repository.change(reviewed) }
                Button("Change other worktree") { repository.change(other) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        .preferredColorScheme(.light)
        .transaction { transaction in
            if ProcessInfo.processInfo.arguments.contains("disable-test-animations") {
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        }
    }

    private var worktrees: some View {
            MacWorktreeScreen(
                model: sidebar, selection: $selection, onPairAgain: {},
                onOpenSettings: nil, onOpenProjects: nil,
                source: { Text("Fixture Mac") }, settings: { Text("Fixture settings") }
            ) { id, name, _, sidebar in
                WorktreeDiffScreen(
                    worktreeName: name,
                    model: ClientViewerModel(
                        worktree: id, macName: "Fixture Mac", repository: repository,
                        commentStore: FakeReviewCommentStore(), pasteboard: FakeReviewPasteboard(),
                        highlighter: FakeSyntaxHighlighter(), copyingLogs: FakeDiagnosticLogsCopying(answering: .success(())),
                        announcing: FakeDiffReadAnnouncing(),
                        onViewedCountChanged: { id, count in sidebar.recordViewedCount(count, on: id) },
                        longWait: .seconds(60)
                    ),
                    onPairAgain: {}
                )
            }
    }

    private var controls: some View {
                VStack {
                    Text("Review reads")
                        .accessibilityIdentifier("live-probe.reads")
                        .accessibilityValue(String(repository.readCount(in: reviewed)))
                    Text("Live subscriptions")
                        .accessibilityIdentifier("live-probe.subscriptions")
                        .accessibilityValue(String(repository.subscriptionCount))
                    Text("Other revision")
                        .accessibilityIdentifier("live-probe.otherRevision")
                        .accessibilityValue(String(repository.revision(in: other)))
                    ContextAnimationProbe().frame(height: 20)
                }
                .font(.caption)
    }
}

private struct LiveWorktreePreferences: WorktreeListPreferences {
    func mode() -> WorktreeListMode { .groupedByProject }
    func remember(_ mode: WorktreeListMode) {}
    func showsQuietWorktrees() -> Bool { true }
    func rememberShowingQuietWorktrees(_ shows: Bool) {}
}

private struct LiveWorktreeAnnouncements: WorktreeReadAnnouncing {
    @MainActor func announce(_ announcement: WorktreeReadAnnouncement) {}
}
