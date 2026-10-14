import Observation
import QuartzCore
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
        let initialInset = scroll.adjustedContentInset
        scroll.setContentOffset(CGPoint(x: 0, y: initialOffset + scrollOffset), animated: false)
        scenario.settleLayout()
        // Both positions are inside the first file and beyond its natural header.
        try #require(abs(scroll.contentOffset.y - initialOffset - scrollOffset) < 2)
        try #require(scenario.model.entries[0].collapse.isCollapsed == false)
        let offsetBeforeCollapse = scroll.contentOffset.y
        let contentHeightBeforeCollapse = scroll.contentSize.height
        let collapseStarted = Date()

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
        #expect(
            abs(scroll.contentOffset.y - initialOffset - DiffCollapsedFileBar.height - 10) < 2,
            """
            collapse=\(collapse), requestedScroll=\(scrollOffset), initialOffset=\(initialOffset)
            offsetBeforeCollapse=\(offsetBeforeCollapse), endOffset=\(scroll.contentOffset.y)
            initialAdjustedInset=\(initialInset), endAdjustedInset=\(scroll.adjustedContentInset)
            contentInset=\(scroll.contentInset), safeArea=\(scroll.safeAreaInsets)
            nextNaturalStart=\(initialOffset + DiffCollapsedFileBar.height + 10)
            contentHeightBefore=\(contentHeightBeforeCollapse), contentHeightAfter=\(scroll.contentSize.height)
            bounds=\(scroll.bounds), settleElapsed=\(Date().timeIntervalSince(collapseStarted))
            windowIsKey=\(scenario.window.isKeyWindow)
            """
        )
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

    @Test(arguments: [PinnedFileCollapse.viewed, .manual])
    func `given a pinned file when collapsed then the viewport and successor header arrive in one coherent motion`(
        collapse: PinnedFileCollapse
    ) async throws {
        // given
        let entries = ["Sources/First.swift", "Sources/Next.swift", "Sources/Last.swift"]
            .map { aRenderedFile(path: $0, lineCount: 160) }
        let scenario = try Scenario(entries: entries)
        defer { scenario.close() }
        scenario.settleLayout()
        let scroll = try #require(scenario.verticalScroll)
        let initialOffset = scroll.contentOffset.y
        scroll.setContentOffset(CGPoint(x: 0, y: initialOffset + 450), animated: false)
        scenario.settleLayout()
        try #require(abs(scroll.contentOffset.y - initialOffset - 450) < 2)
        let probe = ViewportMotionProbe(scroll: scroll)
        probe.start()
        defer { probe.stop() }
        let observationReadyDeadline = CACurrentMediaTime() + 1
        while probe.samples.count < 3, CACurrentMediaTime() < observationReadyDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(probe.samples.count >= 3)
        probe.beginTransition()
        let first = try #require(probe.samples.first)
        try #require(abs(first.presentationOffset - scroll.contentOffset.y) < 2)
        try #require(first.headerFrames.count == 1)
        let originalHeader = try #require(first.headerFrames.first)

        // when
        switch collapse {
        case .viewed:
            scenario.model.setViewed(true, fileId: entries[0].id)
        case .manual:
            scenario.model.setOpen(false, fileId: entries[0].id)
        }
        // Sample actual display frames rather than counting run-loop turns or observing only the
        // model offset, which can already hold the destination while the screen is still moving.
        // Suspension lets queued MainActor work and UIKit's outer event loop run between frames.
        try await Task.sleep(for: .seconds(1.2))
        probe.stop()

        // then
        try #require(probe.missingPresentationFrames == 0)
        let last = try #require(probe.samples.last)
        let finalOffset = initialOffset + DiffCollapsedFileBar.height + 10
        let expectedTravel: CGFloat = 450 - DiffCollapsedFileBar.height - 10
        let intermediateFrames = probe.samples.filter {
            $0.presentationOffset < first.presentationOffset - 2
                && $0.presentationOffset > finalOffset + 2
        }.count
        let largestFrameStep = zip(probe.samples, probe.samples.dropFirst())
            .map { abs($0.presentationOffset - $1.presentationOffset) }
            .max() ?? 0
        // Identify the opaque successor at the exact final slot, then follow its model-layer
        // identity backwards. The outgoing first header is a separate layer that fades away.
        let finalSuccessors = last.headerFrames.filter {
            $0.identity != originalHeader.identity
                && $0.opacity > 0.99
                && abs($0.frame.minY - originalHeader.frame.minY) < 2
        }
        try #require(finalSuccessors.count == 1)
        let successor = try #require(finalSuccessors.first)
        let viewportArrival = try #require(probe.samples.first {
            abs($0.presentationOffset - finalOffset) < 2
        })
        let successorAtArrival = try #require(viewportArrival.headerFrames.first {
            $0.identity == successor.identity
        })
        let successorLag = abs(successorAtArrival.frame.minY - successor.frame.minY)
        let trace = probe.samples.map {
            "time=\($0.elapsed), callbackTime=\($0.callbackElapsed), captureDuration=\($0.captureDuration), model=\($0.modelOffset), presentation=\($0.presentationOffset), headers=\($0.headerFrames)"
        }.joined(separator: "\n")
        let diagnostic = Comment(rawValue: """
        collapse=\(collapse), startPresentation=\(first.presentationOffset), endPresentation=\(last.presentationOffset)
        intermediateFrames=\(intermediateFrames), largestFrameStep=\(largestFrameStep), expectedTravel=\(expectedTravel)
        viewportArrivalTime=\(viewportArrival.elapsed), successorAtArrival=\(successorAtArrival.frame.minY)
        successorFinalPosition=\(successor.frame.minY), successorLag=\(successorLag)
        \(trace)
        """)
        #expect(abs(scroll.contentOffset.y - finalOffset) < 2, diagnostic)
        #expect(abs(last.presentationOffset - finalOffset) < 2, diagnostic)
        // A quarter of the whole journey in one display frame is a generous detector for a snap,
        // while requiring several intermediate frames proves that the viewport visibly travelled.
        #expect(intermediateFrames >= 3, diagnostic)
        #expect(largestFrameStep < expectedTravel / 4, diagnostic)
        // A whole header of remaining travel after the viewport has arrived is a second visible
        // movement, rather than the two parts arriving as one gesture.
        #expect(successorLag < DiffFileHeader.height, diagnostic)
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
            let observation = RenderSettlementProbe(root: root)
            observation.start()
            defer { observation.stop() }
            let deadline = CACurrentMediaTime() + 3
            // Completion is five unchanged native frames with no remaining scroll animation,
            // rather than a count of run-loop turns that may return immediately.
            while observation.quietFrames < 5, CACurrentMediaTime() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
            #expect(
                observation.quietFrames >= 5,
                "Native rendering did not settle: frames=\(observation.frameCount), quietFrames=\(observation.quietFrames)"
            )
        }

    }
}

enum PinnedFileCollapse: Sendable {
    case viewed
    case manual
}

private struct ScrollRendering: Equatable {
    let bounds: CGRect
    let presentationBounds: CGRect
    let contentSize: CGSize
    let adjustedInset: UIEdgeInsets
}

@MainActor
private final class RenderSettlementProbe: NSObject {
    private(set) var quietFrames = 0
    private(set) var frameCount = 0

    private let root: UIView
    private var previousScrollGeometry: [ObjectIdentifier: ScrollRendering] = [:]
    private lazy var displayLink = CADisplayLink(target: self, selector: #selector(observeFrame(_:)))

    init(root: UIView) {
        self.root = root
        super.init()
    }

    func start() {
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        displayLink.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink.invalidate()
    }

    @objc private func observeFrame(_ displayLink: CADisplayLink) {
        root.layoutIfNeeded()
        frameCount += 1
        var scrollGeometry: [ObjectIdentifier: ScrollRendering] = [:]
        var nativeScrolling = false
        var remainingViews = [root]
        while let view = remainingViews.popLast() {
            if let scroll = view as? UIScrollView,
               scroll.bounds.height > 100,
               scroll.contentSize.height > scroll.bounds.height,
               let presentation = scroll.layer.presentation() {
                scrollGeometry[ObjectIdentifier(scroll)] = ScrollRendering(
                    bounds: scroll.bounds,
                    presentationBounds: presentation.bounds,
                    contentSize: scroll.contentSize,
                    adjustedInset: scroll.adjustedContentInset
                )
                nativeScrolling = nativeScrolling || scroll.isScrollAnimating
                    || abs(presentation.bounds.minY - scroll.bounds.minY) >= 0.1
            }
            remainingViews.append(contentsOf: view.subviews)
        }
        if scrollGeometry.isEmpty == false,
           scrollGeometry == previousScrollGeometry,
           nativeScrolling == false {
            quietFrames += 1
        } else {
            quietFrames = 0
        }
        previousScrollGeometry = scrollGeometry
    }
}

private struct ViewportMotionSample {
    let elapsed: CFTimeInterval
    let callbackElapsed: CFTimeInterval
    let captureDuration: CFTimeInterval
    let modelOffset: CGFloat
    let presentationOffset: CGFloat
    let headerFrames: [HeaderPresentation]
}

private struct HeaderPresentation {
    let identity: ObjectIdentifier
    let frame: CGRect
    let opacity: Float
}

@MainActor
private final class ViewportMotionProbe: NSObject {
    private(set) var samples: [ViewportMotionSample] = []
    private(set) var missingPresentationFrames = 0

    private let scroll: UIScrollView
    private var startedAt: CFTimeInterval
    private lazy var displayLink = CADisplayLink(target: self, selector: #selector(sampleFrame(_:)))

    init(scroll: UIScrollView) {
        self.scroll = scroll
        startedAt = CACurrentMediaTime()
        super.init()
    }

    func start() {
        capture(at: CACurrentMediaTime())
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        displayLink.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink.invalidate()
    }

    func beginTransition() {
        startedAt = CACurrentMediaTime()
        samples.removeAll()
        missingPresentationFrames = 0
        capture(at: startedAt)
    }

    @objc private func sampleFrame(_ displayLink: CADisplayLink) {
        capture(at: displayLink.timestamp)
    }

    private func capture(at timestamp: CFTimeInterval) {
        let callbackStarted = CACurrentMediaTime()
        guard let presentation = scroll.layer.presentation() else {
            missingPresentationFrames += 1
            return
        }
        var remaining = [scroll.layer]
        var headerFrames: [HeaderPresentation] = []
        while let layer = remaining.popLast() {
            if abs(layer.bounds.height - DiffFileHeader.height) < 0.5,
               abs(layer.bounds.width - scroll.bounds.width) < 2,
               let drawn = layer.presentation() {
                var opacity = drawn.opacity
                var ancestor = drawn.superlayer
                while let parent = ancestor {
                    opacity *= parent.opacity
                    if parent.isHidden { opacity = 0 }
                    ancestor = parent.superlayer
                }
                headerFrames.append(HeaderPresentation(
                    identity: ObjectIdentifier(layer),
                    frame: drawn.convert(drawn.bounds, to: nil),
                    opacity: drawn.isHidden ? 0 : opacity
                ))
            }
            remaining.append(contentsOf: layer.sublayers ?? [])
        }
        samples.append(ViewportMotionSample(
            elapsed: timestamp - startedAt,
            callbackElapsed: callbackStarted - startedAt,
            captureDuration: CACurrentMediaTime() - callbackStarted,
            modelOffset: scroll.contentOffset.y,
            presentationOffset: presentation.bounds.origin.y,
            headerFrames: headerFrames
        ))
    }
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
