import Observation
import SwiftUI
import Testing
import UIKit

import ClientViewerDomain
import ClientViewerUi
import CoreDiffDomain

@Suite("Continuous diff collapse interaction", .serialized)
@MainActor
struct ContinuousDiffCollapseInteractionTests {

    @Test(arguments: [PinnedFileCollapse.viewed, .manual], [DiffFileHeader.height + 1, 450])
    func `given a file header pinned above its natural position when collapsed then the next file starts at the viewport top`(
        collapse: PinnedFileCollapse,
        scrollOffset: CGFloat
    ) throws {
        // given
        let paths = ["Sources/First.swift", "Sources/Next.swift", "Sources/Last.swift"]
        let entries = paths.map { aRenderedFile(path: $0, lineCount: 160) }
        let scenario = try Scenario(entries: entries)
        defer { scenario.close() }
        scenario.settleLayout()
        let scroll = try #require(scenario.verticalScroll)
        let initialOffset = scroll.contentOffset.y
        scroll.setContentOffset(CGPoint(x: 0, y: initialOffset + scrollOffset), animated: false)
        scenario.settleLayout()
        // Both positions are inside the first file and beyond its natural header.
        try #require(abs(scroll.contentOffset.y - initialOffset - scrollOffset) < 2)
        try #require(scenario.model.entries[0].collapse.isCollapsed == false)

        // when
        // Public UIKit accessibility traversal does not expose SwiftUI's virtual button tree in
        // this host. Drive the same bound state transition without claiming to press the control.
        switch collapse {
        case .viewed:
            scenario.model.setViewed(true, fileId: entries[0].id)
        case .manual:
            scenario.model.setOpen(false, fileId: entries[0].id)
        }
        scenario.settleLayout()

        // then
        try #require(scenario.model.entries[0].collapse.isCollapsed)
        // A pinned next header alone would also pass after skipping hundreds of its code rows.
        // Its natural start must land at the top, with the first file's 44pt bar and 10pt gap above.
        #expect(abs(scroll.contentOffset.y - initialOffset - DiffCollapsedFileBar.height - 10) < 2)
    }

    @Test
    func `given a short file whose natural header is in the viewport when marked viewed then the scroll position stays unchanged`() throws {
        // given
        let entries = [
            aRenderedFile(path: "Sources/Short.swift", lineCount: 8),
            aRenderedFile(path: "Sources/Next.swift", lineCount: 160),
            aRenderedFile(path: "Sources/Last.swift", lineCount: 160)
        ]
        let scenario = try Scenario(entries: entries)
        defer { scenario.close() }
        scenario.settleLayout()
        let scroll = try #require(scenario.verticalScroll)
        let initialOffset = scroll.contentOffset.y
        try #require(abs(initialOffset + scroll.adjustedContentInset.top) < 2)
        try #require(scenario.model.entries[0].collapse.isCollapsed == false)

        // when
        scenario.model.setViewed(true, fileId: entries[0].id)
        scenario.settleLayout()

        // then
        try #require(scenario.model.entries[0].file.isViewed)
        #expect(abs(scroll.contentOffset.y - initialOffset) < 2)
    }

    @Test
    func `given the last file is pinned when marked viewed then the scroll clamps at the new end of content`() throws {
        // given
        let entries = ["Sources/First.swift", "Sources/Next.swift", "Sources/Last.swift"]
            .map { aRenderedFile(path: $0, lineCount: 160) }
        let scenario = try Scenario(entries: entries)
        defer { scenario.close() }
        scenario.settleLayout()
        let scroll = try #require(scenario.verticalScroll)
        let oldEnd = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        scroll.setContentOffset(CGPoint(x: 0, y: oldEnd), animated: false)
        scenario.settleLayout()
        try #require(abs(scroll.contentOffset.y - oldEnd) < 2)
        try #require(scenario.model.entries[2].collapse.isCollapsed == false)

        // when
        scenario.model.setViewed(true, fileId: entries[2].id)
        scenario.settleLayout()

        // then
        try #require(scenario.model.entries[2].collapse.isCollapsed)
        let newEnd = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        try #require(newEnd < oldEnd)
        #expect(abs(scroll.contentOffset.y - newEnd) < 2)
    }

    @Test
    func `given a pinned file follows a viewed file when marked viewed then both collapsed bars stay above the next file`() throws {
        // given
        let entries = [
            aRenderedFile(path: "Sources/First.swift", lineCount: 8).viewed(true),
            aRenderedFile(path: "Sources/Middle.swift", lineCount: 160),
            aRenderedFile(path: "Sources/Next.swift", lineCount: 160)
        ]
        let scenario = try Scenario(entries: entries)
        defer { scenario.close() }
        scenario.settleLayout()
        let scroll = try #require(scenario.verticalScroll)
        let initialOffset = scroll.contentOffset.y
        scroll.setContentOffset(CGPoint(x: 0, y: initialOffset + 450), animated: false)
        scenario.settleLayout()
        try #require(abs(scroll.contentOffset.y - initialOffset - 450) < 2)
        try #require(scenario.model.entries[0].collapse.isCollapsed)
        try #require(scenario.model.entries[1].collapse.isCollapsed == false)

        // when
        scenario.model.setViewed(true, fileId: entries[1].id)
        scenario.settleLayout()

        // then
        try #require(scenario.model.entries[0].collapse.isCollapsed)
        try #require(scenario.model.entries[1].collapse.isCollapsed)
        #expect(abs(scroll.contentOffset.y - initialOffset - 2 * (DiffCollapsedFileBar.height + 10)) < 2)
    }

    // MARK: - Scenario

    @MainActor
    private struct Scenario {
        let model: CollapseHarness
        let controller: UIHostingController<CollapseHarnessView>
        let window: UIWindow
        let previousWindow: UIWindow?

        var verticalScroll: UIScrollView? {
            guard let root = controller.view else { return nil }
            var remaining = [root]
            while let view = remaining.popLast() {
                if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height {
                    return scroll
                }
                remaining.append(contentsOf: view.subviews)
            }
            return nil
        }

        init(entries: [ContinuousDiffEntry]) throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            previousWindow = scene.windows.first(where: \.isKeyWindow)
            model = CollapseHarness(entries: entries)
            controller = UIHostingController(rootView: CollapseHarnessView(model: model))
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = controller
            window.makeKeyAndVisible()
        }

        func close() {
            window.isHidden = true
            previousWindow?.makeKey()
        }

        func settleLayout() {
            guard let root = controller.viewIfLoaded else { return }
            // Drain SwiftUI layout and the disclosure animation on the app-hosted main run loop.
            for _ in 0..<60 {
                root.layoutIfNeeded()
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
        }

    }
}

enum PinnedFileCollapse: Sendable {
    case viewed
    case manual
}

@MainActor
private func aRenderedFile(path: String, lineCount: Int) -> ContinuousDiffEntry {
    let lines = (1...lineCount).map { (number: Int) in
        DiffLine(
            kind: .addition,
            oldNumber: nil,
            newNumber: number,
            text: "let value\(number) = \(number)",
            displayColumns: 20,
            segments: nil
        )
    }
    return .ready(FileDiff(
        file: aChangedFile(
            path: path,
            status: .added,
            insertions: lines.count,
            deletions: 0,
            estimatedLineCount: lines.count
        ),
        hunks: [Hunk(
            index: 0,
            oldStart: 0,
            oldCount: 0,
            newStart: 1,
            newCount: lines.count,
            sectionHeading: nil,
            lines: lines
        )],
        oldLineCount: 0,
        newLineCount: lines.count,
        isTruncated: false,
        truncationReason: nil
    ))
}

@MainActor
@Observable
private final class CollapseHarness {
    var entries: [ContinuousDiffEntry]

    init(entries: [ContinuousDiffEntry]) {
        self.entries = entries
    }

    func setViewed(_ isViewed: Bool, fileId: FileID) {
        entries = entries.map { $0.id == fileId ? $0.viewed(isViewed) : $0 }
    }

    func setOpen(_ isOpen: Bool, fileId: FileID) {
        entries = entries.map { $0.id == fileId ? $0.opened(isOpen) : $0 }
    }
}

@MainActor
private struct CollapseHarnessView: View {
    let model: CollapseHarness

    var body: some View {
        NavigationStack {
            ContinuousDiffView(
                state: .reading(model.entries),
                logCopyState: .ready,
                pointSize: SnapshotLayout.iPhoneLight.codePointSize,
                jumpTarget: nil,
                isWaitingLong: false,
                onReading: { _ in },
                onRereading: { _ in },
                onJumped: {},
                onSetViewed: model.setViewed,
                onSetOpen: model.setOpen,
                onExpand: { _, _, _ in },
                onOpenImage: { _, _ in },
                onRetryImage: { _, _ in },
                onRetry: {},
                onRefresh: {},
                onCopyLogs: {}
            )
            .navigationTitle("Changes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
