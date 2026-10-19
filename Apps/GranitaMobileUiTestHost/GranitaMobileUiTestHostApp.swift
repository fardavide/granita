import SwiftUI

import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain

/// Offline composition for touch tests. The reader and its gesture hierarchy are production views.
@main
struct GranitaMobileUiTestHostApp: App {
    var body: some Scene {
        WindowGroup { HorizontalSwipeFixture() }
    }
}

@MainActor
private struct HorizontalSwipeFixture: View {
    @State private var entries = ["Sources/First.swift", "Sources/Middle.swift", "Sources/Last.swift"]
        .enumerated().map { index, path in
            let text = "let leadingValue = [" + String(repeating: "12345, ", count: 20) + "] // trailingValue"
            let lines = (1...(index == 0 ? 20 : 160)).map { number in
                DiffLine(kind: .addition, oldNumber: nil, newNumber: number, text: text, displayColumns: text.count, segments: nil)
            }
            return ContinuousDiffEntry.ready(FileDiff(
                file: FileChange(
                    id: FileID(repositoryRelativePath: path), path: path, oldPath: nil, status: .added,
                    isBinary: false, isSubmodule: false,
                    stats: ChangeStats(filesChanged: 1, insertions: lines.count, deletions: 0),
                    contentHash: String(repeating: "b", count: 64), estimatedLineCount: lines.count,
                    isViewed: false, isTruncated: false, language: "swift"
                ),
                hunks: [Hunk(index: 0, oldStart: 0, oldCount: 0, newStart: 1, newCount: lines.count, sectionHeading: nil, lines: lines)],
                oldLineCount: 0, newLineCount: lines.count, isTruncated: false, truncationReason: nil
            ))
        }
    @State private var probe = HorizontalSwipeProbe()

    var body: some View {
        NavigationStack {
            ContinuousDiffView(
                state: .reading(entries), logCopyState: .ready, pointSize: 11,
                jumpTarget: nil, isWaitingLong: false,
                onReading: { _ in }, onRereading: { _ in }, onJumped: {},
                onSetViewed: { value, id in entries = entries.map { $0.id == id ? $0.viewed(value) : $0 } },
                onSetOpen: { value, id in entries = entries.map { $0.id == id ? $0.opened(value) : $0 } },
                onExpand: { _, _, _ in }, onOpenImage: { _, _ in }, onRetryImage: { _, _ in },
                onRetry: {}, onRefresh: {}, onCopyLogs: {}
            )
            .navigationTitle("Swipe fixture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Observe swipe") { probe.arm() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SwipeProbeView(probe: probe).frame(height: 120)
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct SwipeProbeView: UIViewRepresentable {
    let probe: HorizontalSwipeProbe

    func makeUIView(context: Context) -> HorizontalSwipeProbe { probe }
    func updateUIView(_ uiView: HorizontalSwipeProbe, context: Context) {}
}
