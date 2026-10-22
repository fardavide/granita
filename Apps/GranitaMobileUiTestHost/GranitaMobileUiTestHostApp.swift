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
            let hasGap = index == 0 && ProcessInfo.processInfo.arguments.contains("selection-gap")
            let lineNumbers = hasGap ? Array(1...10) + Array(15...24) : Array(1...(index == 0 ? 20 : 160))
            let lines = lineNumbers.map { number in
                DiffLine(kind: .addition, oldNumber: nil, newNumber: number, text: text, displayColumns: text.count, segments: nil)
            }
            let hunks = hasGap ? [
                Hunk(index: 0, oldStart: 0, oldCount: 0, newStart: 1, newCount: 10, sectionHeading: nil, lines: Array(lines.prefix(10))),
                Hunk(index: 1, oldStart: 0, oldCount: 0, newStart: 15, newCount: 10, sectionHeading: nil, lines: Array(lines.suffix(10)))
            ] : [Hunk(index: 0, oldStart: 0, oldCount: 0, newStart: 1, newCount: lines.count, sectionHeading: nil, lines: lines)]
            let lineCount = hasGap ? 24 : lines.count
            return ContinuousDiffEntry.ready(FileDiff(
                file: FileChange(
                    id: FileID(repositoryRelativePath: path), path: path, oldPath: nil, status: .added,
                    isBinary: false, isSubmodule: false,
                    stats: ChangeStats(filesChanged: 1, insertions: lines.count, deletions: 0),
                    contentHash: String(repeating: "b", count: 64), estimatedLineCount: lineCount,
                    isViewed: false, isTruncated: false, language: "swift"
                ),
                hunks: hunks,
                oldLineCount: 0, newLineCount: lineCount, isTruncated: false, truncationReason: nil
            ))
        }
    @State private var probe = HorizontalSwipeProbe()
    @State private var draft = CommentDraft.idle

    var body: some View {
        NavigationStack {
            ContinuousDiffView(
                state: .reading(entries), logCopyState: .ready, pointSize: 11,
                jumpTarget: nil, pending: draft.held ?? draft.pending, isWaitingLong: false,
                onReading: { _ in }, onRereading: { _ in }, onJumped: {},
                onSetViewed: { value, id in entries = entries.map { $0.id == id ? $0.viewed(value) : $0 } },
                onSetOpen: { value, id in entries = entries.map { $0.id == id ? $0.opened(value) : $0 } },
                onExpand: { _, _, _ in },
                onTapGutter: { end, file in draft = draft.tapped(end, in: file) },
                onLongPressGutter: { end, file in draft = draft.longPressed(end, in: file) },
                onDragGutter: { end, file in draft = draft.dragged(to: end, in: file) },
                onEndGutterDrag: { draft = draft.finishedDragging() },
                onOpenImage: { _, _ in }, onRetryImage: { _, _ in },
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
                    .overlay(alignment: .bottomTrailing) {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("Held line")
                                .accessibilityIdentifier("selection-probe.heldLine")
                                .accessibilityValue(draft.heldEnd?.newNumber.map(String.init) ?? "none")
                            Text("Composer range")
                                .accessibilityIdentifier("selection-probe.composerRange")
                                .accessibilityValue(draft.pending.map {
                                    "\($0.from.newNumber.map(String.init) ?? "none"):\($0.to.newNumber.map(String.init) ?? "none")"
                                } ?? "none")
                        }
                        .font(.caption)
                        .padding(4)
                        .background(.background)
                    }
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
