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

    @Test(
        arguments: [PinnedFileCollapse.viewed, .manual],
        [DiffMotionFixture.plain, .wordDiff, .unsegmentedWordDiff, .wordDiffOutgoing, .wordDiffSuccessor]
    )
    func `given a pinned file when collapsed then the viewport and successor header arrive in one coherent motion`(
        collapse: PinnedFileCollapse,
        fixture: DiffMotionFixture
    ) async throws {
        // given
        let entries = ["Sources/First.swift", "Sources/Next.swift", "Sources/Last.swift"]
            .enumerated().map { index, path in
                switch fixture {
                case .plain: aRenderedFile(path: path, lineCount: 160)
                case .wordDiff: aRenderedWordDiffFile(path: path)
                case .unsegmentedWordDiff: aRenderedWordDiffFile(path: path, segmented: false)
                case .wordDiffOutgoing: aRenderedWordDiffFile(path: path, segmented: index == 0)
                case .wordDiffSuccessor: aRenderedWordDiffFile(path: path, segmented: index == 1)
                }
            }
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
        try #require(first.headerFrames.count == 1, "Initial header candidates: \(first.headerCandidates)")
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
        let finalOffset = initialOffset + DiffCollapsedFileBar.height + 10
        let expectedTravel: CGFloat = 450 - DiffCollapsedFileBar.height - 10
        let intermediateFrames = probe.samples.filter {
            $0.presentationOffset < first.presentationOffset - 2
                && $0.presentationOffset > finalOffset + 2
        }.count
        let largestFrameStep = zip(probe.samples, probe.samples.dropFirst())
            .map { abs($0.presentationOffset - $1.presentationOffset) }
            .max() ?? 0
        let observedViewportArrivalIndex = probe.samples.firstIndex {
            abs($0.presentationOffset - finalOffset) < 2
        }
        // Build the bounded trace before requiring a final successor, so an unfinished arrival
        // reports the same native samples as a frame-step or coherence failure.
        let largestStepEndIndex = (1..<probe.samples.count).max { left, right in
            abs(probe.samples[left].presentationOffset - probe.samples[left - 1].presentationOffset)
                < abs(probe.samples[right].presentationOffset - probe.samples[right - 1].presentationOffset)
        } ?? 0
        var traceIndices = Set(probe.samples.indices.prefix(4))
        traceIndices.formUnion((largestStepEndIndex - 2...largestStepEndIndex).filter(probe.samples.indices.contains))
        if let observedViewportArrivalIndex {
            traceIndices.formUnion((observedViewportArrivalIndex - 2...observedViewportArrivalIndex + 2).filter(probe.samples.indices.contains))
        }
        traceIndices.formUnion(probe.samples.indices.suffix(2))
        let trace = traceIndices.sorted().map { index in
            let sample = probe.samples[index]
            return "sample=\(index), time=\(sample.elapsed), callbackTime=\(sample.callbackElapsed), captureDuration=\(sample.captureDuration), model=\(sample.modelOffset), presentation=\(sample.presentationOffset), headers=\(sample.headerFrames)"
        }.joined(separator: "\n")
        let observationDiagnostic = Comment(rawValue: """
        collapse=\(collapse), fixture=\(fixture), startPresentation=\(first.presentationOffset)
        endPresentation=\(String(describing: probe.samples.last?.presentationOffset)), endModel=\(scroll.contentOffset.y), finalOffset=\(finalOffset)
        missingPresentationFrames=\(probe.missingPresentationFrames), sampleCount=\(probe.samples.count)
        intermediateFrames=\(intermediateFrames), largestFrameStep=\(largestFrameStep), expectedTravel=\(expectedTravel)
        viewportArrivalIndex=\(String(describing: observedViewportArrivalIndex)), originalHeader=\(originalHeader)
        \(trace)
        """)
        try #require(probe.missingPresentationFrames == 0, observationDiagnostic)
        let last = try #require(probe.samples.last, observationDiagnostic)
        // Identify the opaque successor at the exact final slot, then follow its model-layer
        // identity backwards. The outgoing first header is a separate layer that fades away.
        let finalSuccessors = last.headerFrames.filter {
            $0.identity != originalHeader.identity
                && $0.opacity > 0.99
                && abs($0.frame.minY - originalHeader.frame.minY) < 2
        }
        try #require(finalSuccessors.count == 1, observationDiagnostic)
        let successor = try #require(finalSuccessors.first, observationDiagnostic)
        let viewportArrivalIndex = try #require(observedViewportArrivalIndex, observationDiagnostic)
        let viewportArrival = probe.samples[viewportArrivalIndex]
        let successorAtArrival = try #require(viewportArrival.headerFrames.first {
            $0.identity == successor.identity
        }, observationDiagnostic)
        let successorLag = abs(successorAtArrival.frame.minY - successor.frame.minY)
        let firstViewportMovementIndex = probe.samples.firstIndex {
            abs($0.presentationOffset - first.presentationOffset) >= 2
        }
        let firstSuccessorIndex = probe.samples.firstIndex { sample in
            sample.headerFrames.contains { $0.identity == successor.identity }
        }
        let firstSuccessorFrame = firstSuccessorIndex.flatMap { index in
            probe.samples[index].headerFrames.first { $0.identity == successor.identity }?.frame
        }
        let firstSuccessorMovementIndex = firstSuccessorFrame.flatMap { initialFrame in
            probe.samples.firstIndex { sample in
                sample.headerFrames.contains {
                    $0.identity == successor.identity && abs($0.frame.minY - initialFrame.minY) >= 2
                }
            }
        }
        let clockMilestones = Set([
            0, firstViewportMovementIndex, firstSuccessorIndex, firstSuccessorMovementIndex,
            viewportArrivalIndex, probe.samples.indices.last
        ].compactMap { $0 })
        var previousClocks: [ObjectIdentifier: NativeLayerTiming] = [:]
        var nativeClockEvents: [String] = []
        for (index, sample) in probe.samples.enumerated() {
            for clock in sample.nativeClocks {
                if previousClocks[clock.timing.identity] != clock.timing || clockMilestones.contains(index) {
                    nativeClockEvents.append("sample=\(index), callbackTime=\(sample.callbackElapsed), localTime=\(clock.localTime), modelFrame=\(clock.modelFrame), clock=\(clock.timing)")
                }
                previousClocks[clock.timing.identity] = clock.timing
            }
        }
        let nativeClockTrace = nativeClockEvents.prefix(100).joined(separator: "\n")
        // A moving wrapper is not enough: every matching descendant of the unchanged successor
        // must occupy the same presentation rectangle. The outgoing header's opacity may crossfade.
        let successorDescendantGeometry = probe.samples.enumerated().flatMap { index, sample -> [NestedHeaderGeometry] in
            let retained = sample.headerFrames.first { $0.identity == successor.identity }
            return sample.headerCandidates.filter {
                $0.ancestorIdentities.contains(successor.identity)
            }.map { candidate in
                NestedHeaderGeometry(sampleIndex: index, retained: retained, descendant: candidate.header)
            }
        }
        let misalignedSuccessorDescendants = successorDescendantGeometry.filter { geometry in
            guard let retained = geometry.retained else { return true }
            return abs(retained.frame.minX - geometry.descendant.frame.minX) >= 2
                || abs(retained.frame.minY - geometry.descendant.frame.minY) >= 2
                || abs(retained.frame.width - geometry.descendant.frame.width) >= 2
                || abs(retained.frame.height - geometry.descendant.frame.height) >= 2
        }
        // Bound only diagnostic output; every assertion above and below still uses every sample.
        let diagnostic = Comment(rawValue: """
        collapse=\(collapse), fixture=\(fixture), startPresentation=\(first.presentationOffset), endPresentation=\(last.presentationOffset)
        intermediateFrames=\(intermediateFrames), largestFrameStep=\(largestFrameStep), expectedTravel=\(expectedTravel)
        viewportArrivalTime=\(viewportArrival.elapsed), successorAtArrival=\(successorAtArrival.frame.minY)
        successorFinalPosition=\(successor.frame.minY), successorLag=\(successorLag)
        successorDescendantChecks=\(successorDescendantGeometry.count), misalignedSuccessorDescendants=\(misalignedSuccessorDescendants.count)
        firstMisalignedSuccessorDescendant=\(String(describing: misalignedSuccessorDescendants.first))
        firstViewportMovementCallback=\(String(describing: firstViewportMovementIndex.map { probe.samples[$0].callbackElapsed }))
        firstSuccessorAppearanceCallback=\(String(describing: firstSuccessorIndex.map { probe.samples[$0].callbackElapsed }))
        firstSuccessorMovementCallback=\(String(describing: firstSuccessorMovementIndex.map { probe.samples[$0].callbackElapsed }))
        nativeClockEvents=\(nativeClockEvents.count), shownNativeClockEvents=\(min(nativeClockEvents.count, 100))
        \(trace)
        \(nativeClockTrace)
        """)
        Attachment.record(trace + "\n" + nativeClockTrace, named: "native-motion-\(collapse)-\(fixture).txt")
        #expect(successorDescendantGeometry.contains {
            $0.sampleIndex == viewportArrivalIndex && $0.descendant.opacity > 0.99
        }, diagnostic)
        #expect(misalignedSuccessorDescendants.isEmpty, diagnostic)
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

    @Test(arguments: NativeHunkWidthFixture.allCases, [CGFloat(8), 11, 12, 17])
    func `given native text with its widest line below the viewport when first rendered then horizontal content fits the actual widest line`(
        fixture: NativeHunkWidthFixture,
        pointSize: CGFloat
    ) throws {
        // given
        let candidateTexts: [String]
        switch fixture {
        case .printableAscii:
            candidateTexts = [
                String(repeating: "i", count: 264),
                String(repeating: "W", count: 264),
                String(repeating: ".", count: 264),
                String(repeating: " ", count: 300),
                String(repeating: "x", count: 295) + "          "
            ]
        case .highlightFallback:
            candidateTexts = ["short", String(repeating: "let value = oldValue + newValue; ", count: 8)]
        case .tabs:
            candidateTexts = ["short", String(repeating: "\tlet\tvalue\t=\t42", count: 16)]
        case .cjkRanking:
            // The first candidate has more columns; native font fallback can make the second wider.
            candidateTexts = [String(repeating: "日本語", count: 54), String(repeating: "x", count: 300)]
        case .combiningAndAmbiguous:
            candidateTexts = ["short", String(repeating: "e\u{0301} o\u{0308} caffè — · Ω α ", count: 24)]
        case .emoji:
            candidateTexts = ["short", String(repeating: "family 👨‍👩‍👧 ice 🧊 heart ❤️ ", count: 24)]
        case .controls:
            candidateTexts = ["short", String(repeating: "let value = 42; ", count: 24) + "\r\u{0000}\u{0001}"]
        case .conflictWeight:
            candidateTexts = ["short", "<<<<<<< HEAD " + String(repeating: "feature/long-branch-name-", count: 20)]
        }
        let firstCandidateLine = 161 - candidateTexts.count
        let lines = (1...160).map { number in
            let text = number >= firstCandidateLine ? candidateTexts[number - firstCandidateLine] : "let value = 1"
            return DiffLine(
                kind: fixture == .conflictWeight && number == 160 ? .conflictMarker : .context,
                oldNumber: number,
                newNumber: number,
                text: text,
                displayColumns: DisplayWidth(of: text).columns,
                segments: nil
            )
        }
        let file = aChangedFile(
            path: "Sources/NativeWidth.swift",
            status: fixture == .conflictWeight ? .conflicted : .modified,
            insertions: 0,
            deletions: 0,
            estimatedLineCount: lines.count
        )
        let entry = ContinuousDiffEntry.ready(FileDiff(
            file: file,
            hunks: [Hunk(
                index: 0,
                oldStart: 1,
                oldCount: lines.count,
                newStart: 1,
                newCount: lines.count,
                sectionHeading: nil,
                lines: lines
            )],
            oldLineCount: lines.count,
            newLineCount: lines.count,
            isTruncated: false,
            truncationReason: nil
        ))
        let highlighted: [FileID: HighlightedFile] = fixture == .highlightFallback
            ? [file.id: HighlightedFile(old: [160: AttributedString("short")], new: [160: AttributedString("short")])]
            : [:]
        let scenario = try Scenario(entries: [entry], pointSize: pointSize, highlighted: highlighted)
        defer { scenario.close() }

        // when
        scenario.settleLayout()
        let vertical = try #require(scenario.verticalScroll)
        let horizontal = try #require(scenario.horizontalScroll)
        try #require(abs(vertical.contentOffset.y + vertical.adjustedContentInset.top) < 2)
        try #require(horizontal.bounds.height > 2 * vertical.bounds.height)
        let renderedContentWidth = horizontal.contentSize.width
        let renderedViewportWidth = horizontal.bounds.width
        let scene = try #require(scenario.window.windowScene)
        let oracle = UIHostingController(rootView: AnyView(EmptyView()))
        let oracleWindow = UIWindow(windowScene: scene)
        oracleWindow.frame = scenario.window.frame
        oracleWindow.rootViewController = oracle
        oracleWindow.makeKeyAndVisible()
        defer {
            oracleWindow.isHidden = true
            scenario.window.makeKey()
        }
        let nativeWidths = candidateTexts.enumerated().map { index, text in
            oracle.rootView = AnyView(
                Text(verbatim: MonospacedGrid.expandingTabs(in: text))
                    .font(.system(size: pointSize, weight: fixture == .conflictWeight && index == candidateTexts.count - 1 ? .semibold : .regular, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
            )
            oracle.view.layoutIfNeeded()
            return oracle.sizeThatFits(in: CGSize(width: 100_000, height: 10_000)).width
        }
        let expectedContentWidth = try #require(nativeWidths.max()) + 12
        try #require(expectedContentWidth > renderedViewportWidth)

        // then
        #expect(
            abs(renderedContentWidth - expectedContentWidth) < 2,
            "fixture=\(fixture), pointSize=\(pointSize), nativeWidths=\(nativeWidths), expectedContentWidth=\(expectedContentWidth), actualContentWidth=\(renderedContentWidth)"
        )
    }

    @Test
    func `given a hunk with its widest line below the viewport when first rendered then horizontal travel matches the same line at the top`() throws {
        // given
        let visibleWidth: CGFloat
        do {
            let scenario = try Scenario(entries: [
                aRenderedFile(path: "Sources/Wide.swift", lineCount: 160, widestLineAt: 1)
            ])
            defer { scenario.close() }
            scenario.settleLayout()
            let vertical = try #require(scenario.verticalScroll)
            let horizontal = try #require(scenario.horizontalScroll)
            try #require(abs(vertical.contentOffset.y + vertical.adjustedContentInset.top) < 2)
            try #require(horizontal.bounds.height > vertical.bounds.height)
            try #require(horizontal.contentSize.width > horizontal.bounds.width)
            visibleWidth = horizontal.contentSize.width
        }

        // when
        let scenario = try Scenario(entries: [
            aRenderedFile(path: "Sources/Wide.swift", lineCount: 160, widestLineAt: 160)
        ])
        defer { scenario.close() }
        scenario.settleLayout()
        let vertical = try #require(scenario.verticalScroll)
        let horizontal = try #require(scenario.horizontalScroll)
        try #require(abs(vertical.contentOffset.y + vertical.adjustedContentInset.top) < 2)
        try #require(horizontal.bounds.height > vertical.bounds.height)

        // then
        #expect(horizontal.contentSize.width > horizontal.bounds.width)
        #expect(abs(horizontal.contentSize.width - visibleWidth) < 2)
    }

    @Test(arguments: [PinnedFileCollapse.viewed, .manual])
    func `given the successor header is already visible when the pinned current file collapses then the successor starts at the viewport top`(
        collapse: PinnedFileCollapse
    ) throws {
        // given
        let entries = [
            aRenderedFile(path: "Sources/First.swift", lineCount: 20),
            aRenderedFile(path: "Sources/Next.swift", lineCount: 160)
        ]
        let scenario = try Scenario(entries: entries)
        defer { scenario.close() }
        scenario.settleLayout()
        let scroll = try #require(scenario.verticalScroll)
        let initialOffset = scroll.contentOffset.y
        try #require(abs(initialOffset + scroll.adjustedContentInset.top) < 2)
        scroll.setContentOffset(CGPoint(x: 0, y: initialOffset + 47), animated: false)
        scenario.settleLayout()
        try #require(abs(scroll.contentOffset.y - initialOffset - 47) < 2)
        try #require(scroll.contentOffset.y - initialOffset > DiffFileHeader.height)
        try #require(scenario.model.entries[0].collapse.isCollapsed == false)
        try #require(scenario.visibleHeaders(in: scroll).count == 2)

        // when
        switch collapse {
        case .viewed:
            scenario.model.setViewed(true, fileId: entries[0].id)
        case .manual:
            scenario.model.setOpen(false, fileId: entries[0].id)
        }
        scenario.settleLayout()

        // then
        try #require(scenario.model.entries[0].collapse.isCollapsed)
        #expect(abs(scroll.contentOffset.y - initialOffset - DiffCollapsedFileBar.height - 10) < 2)
    }

    @Test
    func `given a long hunk when scrolled far into its repeated rows then the code remains visibly correct`() throws {
        // given
        let repeatedCode = "let repeatedValue = 12345"
        let expectedCode: Data
        let crop: CGRect
        let referenceContentHeight: CGFloat
        do {
            let reference = try Scenario(entries: [
                aRenderedFile(path: "Sources/Repeated.swift", lineCount: 160, repeatedLine: repeatedCode)
            ])
            defer { reference.close() }
            reference.settleLayout()
            let vertical = try #require(reference.verticalScroll)
            let horizontal = try #require(reference.horizontalScroll)
            try #require(abs(vertical.contentOffset.y + vertical.adjustedContentInset.top) < 2)
            let codePresentation = try #require(horizontal.layer.presentation())
            let codeFrame = codePresentation.convert(codePresentation.bounds, to: nil)
            // The native horizontal scroll contains code, while the changing line-number gutter
            // is outside it. Keep the crop inside its leading edge and clear of hunk chrome.
            crop = CGRect(x: codeFrame.minX + 8, y: codeFrame.minY + 80, width: 200, height: 90)
            try #require(codeFrame.contains(crop))
            referenceContentHeight = horizontal.contentSize.height
            expectedCode = try reference.imageData(in: crop)
        }
        do {
            let blank = try Scenario(entries: [
                aRenderedFile(path: "Sources/Repeated.swift", lineCount: 160, repeatedLine: "")
            ])
            defer { blank.close() }
            blank.settleLayout()
            let blankCode = try blank.imageData(in: crop)
            try #require(expectedCode != blankCode, "The reference code crop does not distinguish text from blank rows")
        }
        let scenario = try Scenario(entries: [
            aRenderedFile(path: "Sources/Repeated.swift", lineCount: 320, repeatedLine: repeatedCode)
        ])
        defer { scenario.close() }
        scenario.settleLayout()
        let vertical = try #require(scenario.verticalScroll)
        let horizontal = try #require(scenario.horizontalScroll)
        let initialOffset = vertical.contentOffset.y
        try #require(abs(initialOffset + vertical.adjustedContentInset.top) < 2)
        // Equal three-digit gutters and identical row text keep geometry the same. Subtracting
        // independently mounted hunk heights removes constant padding from the native row pitch.
        let rowPitch = (horizontal.contentSize.height - referenceContentHeight) / 160
        try #require(rowPitch > 0)
        let travel = rowPitch * 200
        try #require(travel > vertical.bounds.height * 3)
        let pixelTravel = travel * scenario.window.screen.scale
        try #require(abs(pixelTravel - pixelTravel.rounded()) < 0.01, "The comparison must preserve the text's pixel phase")

        // when
        vertical.setContentOffset(CGPoint(x: 0, y: initialOffset + travel), animated: false)
        scenario.settleLayout()

        // then
        try #require(abs(vertical.contentOffset.y - initialOffset - travel) < 2)
        let presentation = try #require(vertical.layer.presentation())
        try #require(presentation.convert(presentation.bounds, to: nil).contains(crop))
        let actualCode = try scenario.imageData(in: crop)
        if actualCode != expectedCode {
            Attachment.record(Array(expectedCode), named: "expected-visible-code.png")
            Attachment.record(Array(actualCode), named: "scrolled-visible-code.png")
        }
        #expect(actualCode == expectedCode, "rowPitch=\(rowPitch), travel=\(travel), crop=\(crop)")
    }

    @Test
    func `given wide code when scrolled horizontally and back then the visible code changes and returns exactly`() throws {
        // given
        let wideCode = "let leadingValue = [" + String(repeating: "12345, ", count: 20) + "] // trailingValue"
        let blankCode: Data
        let blankCrop: CGRect
        do {
            let blank = try Scenario(entries: [
                aRenderedFile(path: "Sources/Wide.swift", lineCount: 160, repeatedLine: "")
            ])
            defer { blank.close() }
            blank.settleLayout()
            let horizontal = try #require(blank.horizontalScroll)
            let presentation = try #require(horizontal.layer.presentation())
            let codeFrame = presentation.convert(presentation.bounds, to: nil)
            blankCrop = CGRect(x: codeFrame.minX + 8, y: codeFrame.minY + 80, width: 200, height: 90)
            try #require(codeFrame.contains(blankCrop))
            blankCode = try blank.imageData(in: blankCrop)
        }
        let scenario = try Scenario(entries: [
            aRenderedFile(path: "Sources/Wide.swift", lineCount: 160, repeatedLine: wideCode)
        ])
        defer { scenario.close() }
        scenario.settleLayout()
        let vertical = try #require(scenario.verticalScroll)
        let horizontal = try #require(scenario.horizontalScroll)
        try #require(abs(vertical.contentOffset.y + vertical.adjustedContentInset.top) < 2)
        try #require(abs(horizontal.contentOffset.x) < 2)
        let maximumOffset = horizontal.contentSize.width - horizontal.bounds.width + horizontal.adjustedContentInset.right
        try #require(maximumOffset > 100)
        let presentation = try #require(horizontal.layer.presentation())
        let codeFrame = presentation.convert(presentation.bounds, to: nil)
        let crop = CGRect(x: codeFrame.minX + 8, y: codeFrame.minY + 80, width: 200, height: 90)
        try #require(codeFrame.contains(crop))
        try #require(crop == blankCrop, "Blank reference and visible code must use identical crop geometry")
        let originalCode = try scenario.imageData(in: crop)

        // when
        horizontal.setContentOffset(CGPoint(x: maximumOffset, y: horizontal.contentOffset.y), animated: false)
        scenario.settleLayout()
        try #require(abs(horizontal.contentOffset.x - maximumOffset) < 2)
        let trailingCode = try scenario.imageData(in: crop)
        horizontal.setContentOffset(CGPoint(x: 0, y: horizontal.contentOffset.y), animated: false)
        scenario.settleLayout()

        // then
        try #require(abs(horizontal.contentOffset.x) < 2)
        let restoredCode = try scenario.imageData(in: crop)
        if originalCode == blankCode || trailingCode == blankCode || trailingCode == originalCode || restoredCode != originalCode {
            Attachment.record(Array(blankCode), named: "horizontal-blank-code.png")
            Attachment.record(Array(originalCode), named: "horizontal-original-code.png")
            Attachment.record(Array(trailingCode), named: "horizontal-trailing-code.png")
            Attachment.record(Array(restoredCode), named: "horizontal-restored-code.png")
        }
        #expect(originalCode != blankCode, "The initial horizontal crop must contain visible code")
        #expect(trailingCode != blankCode, "The trailing horizontal crop must contain visible code")
        #expect(trailingCode != originalCode, "Horizontal travel=\(maximumOffset), crop=\(crop)")
        #expect(restoredCode == originalCode, "Horizontal travel=\(maximumOffset), crop=\(crop)")
    }

    @Test
    func `given the viewport is inside a later file when its code scrolls horizontally then the vertical reading position stays unchanged`() async throws {
        // given
        let wideCode = "let leadingValue = [" + String(repeating: "12345, ", count: 20) + "] // trailingValue"
        let entries = ["Sources/First.swift", "Sources/Middle.swift", "Sources/Last.swift"]
            .map { aRenderedFile(path: $0, lineCount: 160, repeatedLine: wideCode) }
        let scenario = try Scenario(entries: entries)
        defer { scenario.close() }
        scenario.settleLayout()
        let vertical = try #require(scenario.verticalScroll)
        let listTop = vertical.contentOffset.y
        scenario.model.jumpTarget = entries[2].id
        try await scenario.settleJump()
        try #require(scenario.model.readingPositions.contains(2))
        let selectedFileOffset = vertical.contentOffset.y
        vertical.setContentOffset(CGPoint(x: 0, y: selectedFileOffset + 450), animated: false)
        scenario.settleLayout()
        let verticalBefore = vertical.contentOffset.y
        try #require(abs(verticalBefore - selectedFileOffset - 450) < 2, "Selected offset=\(selectedFileOffset), requested=\(selectedFileOffset + 450), actual=\(verticalBefore), presentation=\(String(describing: vertical.layer.presentation()?.bounds)), contentSize=\(vertical.contentSize), viewport=\(vertical.bounds)")
        if verticalBefore - listTop <= vertical.bounds.height * 2 {
            Attachment.record(Array(try scenario.imageData(in: scenario.window.bounds)), named: "later-file-setup.png")
        }
        try #require(
            verticalBefore - listTop > vertical.bounds.height * 2,
            "Initial offset=\(listTop), selected offset=\(selectedFileOffset), actual=\(verticalBefore), contentSize=\(vertical.contentSize), viewport=\(vertical.bounds)"
        )
        let verticalPresentation = try #require(vertical.layer.presentation())
        try #require(abs(verticalPresentation.bounds.minY - verticalBefore) < 2)
        let viewport = verticalPresentation.convert(verticalPresentation.bounds, to: nil)
        // Select the hunk at the fixed code point; multiple hunks can share the viewport.
        let codePoint = CGPoint(x: viewport.midX, y: viewport.minY + 145)
        var remaining: [UIView] = [vertical]
        var visibleHorizontalScrolls: [UIScrollView] = []
        var candidateGeometry: [String] = []
        while let view = remaining.popLast() {
            if let scroll = view as? UIScrollView,
               scroll.bounds.height > 0,
               abs(scroll.contentSize.height - scroll.bounds.height) < 2,
               let presentation = scroll.layer.presentation() {
                let frame = presentation.convert(presentation.bounds, to: nil)
                if frame.contains(codePoint) {
                    visibleHorizontalScrolls.append(scroll)
                    candidateGeometry.append("frame=\(frame), modelOffset=\(scroll.contentOffset), presentationBounds=\(presentation.bounds)")
                }
            }
            remaining.append(contentsOf: view.subviews)
        }
        try #require(visibleHorizontalScrolls.count == 1, "Expected one later-file code scroll at \(codePoint); found \(visibleHorizontalScrolls.count): \(candidateGeometry)")
        let horizontal = try #require(visibleHorizontalScrolls.first)
        try #require(abs(horizontal.contentOffset.x) < 2)
        let maximumOffset = horizontal.contentSize.width - horizontal.bounds.width + horizontal.adjustedContentInset.right
        try #require(maximumOffset > 100)
        let requestedHorizontalOffset = min(maximumOffset, 160)
        let horizontalPresentation = try #require(horizontal.layer.presentation())
        let codeFrame = horizontalPresentation.convert(horizontalPresentation.bounds, to: nil)
        let visibleCode = codeFrame.intersection(viewport)
        // Containing the input point does not imply that a hunk contains a viewport-fixed crop.
        // Translate the whole 200x90 crop into its visible intersection without changing its size.
        let crop = CGRect(x: visibleCode.midX - 100, y: visibleCode.midY - 45, width: 200, height: 90)
        let cropDiagnostic = Comment(rawValue: """
        codePoint=\(codePoint), codeFrame=\(codeFrame), viewport=\(viewport), visibleCode=\(visibleCode), crop=\(crop)
        verticalModelOffset=\(vertical.contentOffset), verticalPresentationBounds=\(verticalPresentation.bounds)
        horizontalModelOffset=\(horizontal.contentOffset), horizontalPresentationBounds=\(horizontalPresentation.bounds)
        """)
        try #require(visibleCode.width >= 200 && visibleCode.height >= 90, cropDiagnostic)
        try #require(codeFrame.contains(crop) && viewport.contains(crop), cropDiagnostic)
        let originalCode = try scenario.imageData(in: crop)
        let verticalProbe = ViewportMotionProbe(scroll: vertical)
        verticalProbe.start()
        defer { verticalProbe.stop() }

        // when
        // This app-hosted harness has no public touch-injection API. Drive native scrolling
        // without claiming to synthesize a pan recognizer or a user's swipe.
        horizontal.setContentOffset(
            CGPoint(x: requestedHorizontalOffset, y: horizontal.contentOffset.y),
            animated: true
        )
        scenario.settleLayout()
        verticalProbe.stop()

        // then
        let horizontalAfter = try #require(horizontal.layer.presentation())
        let verticalAfter = try #require(vertical.layer.presentation())
        let scrolledCode = try scenario.imageData(in: crop)
        let largestVerticalDisplacement = verticalProbe.samples.map {
            max(abs($0.modelOffset - verticalBefore), abs($0.presentationOffset - verticalBefore))
        }.max() ?? 0
        let diagnostic = Comment(rawValue: "horizontalRequested=\(requestedHorizontalOffset), horizontalModel=\(horizontal.contentOffset.x), horizontalPresentation=\(horizontalAfter.bounds.minX), listTop=\(listTop), verticalBefore=\(verticalBefore), verticalModel=\(vertical.contentOffset.y), verticalPresentation=\(verticalAfter.bounds.minY), largestVerticalDisplacement=\(largestVerticalDisplacement), observedFrames=\(verticalProbe.samples.count)")
        if scrolledCode == originalCode || abs(vertical.contentOffset.y - verticalBefore) >= 2 {
            Attachment.record(Array(originalCode), named: "later-file-before-horizontal-scroll.png")
            Attachment.record(Array(scrolledCode), named: "later-file-after-horizontal-scroll.png")
        }
        #expect(abs(horizontal.contentOffset.x - requestedHorizontalOffset) < 2, diagnostic)
        #expect(abs(horizontalAfter.bounds.minX - requestedHorizontalOffset) < 2, diagnostic)
        #expect(scrolledCode != originalCode, diagnostic)
        #expect(verticalProbe.missingPresentationFrames == 0, diagnostic)
        #expect(verticalProbe.samples.isEmpty == false, diagnostic)
        #expect(verticalProbe.samples.allSatisfy {
            abs($0.modelOffset - verticalBefore) < 2 && abs($0.presentationOffset - verticalBefore) < 2
        }, diagnostic)
        #expect(abs(vertical.contentOffset.y - verticalBefore) < 2, diagnostic)
        #expect(abs(verticalAfter.bounds.minY - verticalBefore) < 2, diagnostic)
    }

    @Test(arguments: [PinnedFileCollapse.viewed, .manual])
    func `given a pinned file is collapsing when another file is selected then explicit selection wins over automatic advance`(
        collapse: PinnedFileCollapse
    ) async throws {
        // given
        let entries = [
            aRenderedFile(path: "Sources/First.swift", lineCount: 20),
            aRenderedFile(path: "Sources/Next.swift", lineCount: 20),
            aRenderedFile(path: "Sources/Selected.swift", lineCount: 160)
        ]
        let collapsedFirst: ContinuousDiffEntry
        switch collapse {
        case .viewed: collapsedFirst = entries[0].viewed(true)
        case .manual: collapsedFirst = entries[0].opened(false)
        }
        let expectedSelectedOffset: CGFloat
        do {
            let baseline = try Scenario(
                entries: [collapsedFirst, entries[1], entries[2]]
            )
            defer { baseline.close() }
            baseline.settleLayout()
            let scroll = try #require(baseline.verticalScroll)
            try #require(baseline.model.entries[0].collapse.isCollapsed)
            try #require(baseline.model.jumpTarget == nil)
            let baselineInitialOffset = scroll.contentOffset.y
            try #require(abs(baselineInitialOffset + scroll.adjustedContentInset.top) < 2)
            scroll.setContentOffset(CGPoint(x: 0, y: baselineInitialOffset + 47), animated: false)
            baseline.settleLayout()
            try #require(abs(scroll.contentOffset.y - baselineInitialOffset - 47) < 2)
            // Match the user request on an already mounted scroll, rather than a seeded initial jump.
            baseline.model.jumpTarget = entries[2].id
            try await baseline.settleJump()
            expectedSelectedOffset = scroll.contentOffset.y
            // The selected file must be farther down than automatic advance to the second file.
            try #require(expectedSelectedOffset + scroll.adjustedContentInset.top > DiffCollapsedFileBar.height + 10 + 2)
        }
        let scenario = try Scenario(entries: entries)
        defer { scenario.close() }
        scenario.settleLayout()
        let scroll = try #require(scenario.verticalScroll)
        let initialOffset = scroll.contentOffset.y
        try #require(abs(initialOffset + scroll.adjustedContentInset.top) < 2)
        scroll.setContentOffset(CGPoint(x: 0, y: initialOffset + 47), animated: false)
        scenario.settleLayout()
        try #require(abs(scroll.contentOffset.y - initialOffset - 47) < 2)
        try #require(scroll.contentOffset.y - initialOffset > DiffFileHeader.height)
        try #require(scenario.model.entries[0].collapse.isCollapsed == false)
        try #require(scenario.model.jumpTarget == nil)
        try #require(scenario.visibleHeaders(in: scroll).count == 2)

        // when
        switch collapse {
        case .viewed:
            scenario.model.setViewed(true, fileId: entries[0].id)
        case .manual:
            scenario.model.setOpen(false, fileId: entries[0].id)
        }
        scenario.model.jumpTarget = entries[2].id
        try await scenario.settleJump()

        // then
        try #require(scenario.model.entries[0].collapse.isCollapsed)
        #expect(
            abs(scroll.contentOffset.y - expectedSelectedOffset) < 2,
            "collapse=\(collapse), expectedSelectedOffset=\(expectedSelectedOffset), actualSelectedOffset=\(scroll.contentOffset.y)"
        )
    }

    @Test(arguments: [PinnedFileCollapse.viewed, .manual])
    func `given a collapsing source reopens when its successor mounts then the viewport stays with the source`(
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
        let offsetBeforeCollapse = scroll.contentOffset.y
        try #require(scenario.model.entries[0].collapse.isCollapsed == false)
        let initialHeaders = try scenario.visibleHeaders(in: scroll)
        try #require(initialHeaders.count == 1)
        let sourceHeader = try #require(initialHeaders.first)
        let initialPresentation = try #require(scroll.layer.presentation())
        let initialViewport = initialPresentation.convert(initialPresentation.bounds, to: nil)
        let sourcePosition = CGPoint(
            x: sourceHeader.frame.minX - initialViewport.minX,
            y: sourceHeader.frame.minY - initialViewport.minY
        )
        let sourceHeaderImage = try scenario.imageData(in: sourceHeader.frame)
        try #require(scenario.model.readingPositions.contains(1) == false, "Successor reading was already reported before collapse")
        scenario.model.sourceReopenOnRead = SourceReopenOnRead(
            position: 1,
            sourceId: entries[0].id,
            collapse: collapse,
            scroll: scroll
        )

        // when
        switch collapse {
        case .viewed:
            scenario.model.setViewed(true, fileId: entries[0].id)
        case .manual:
            scenario.model.setOpen(false, fileId: entries[0].id)
        }
        try await scenario.settleSourceReopen()

        // then
        let reopened = try #require(scenario.model.sourceReopenObservation)
        try #require(reopened.sourceWasCollapsed)
        // A callback after viewport movement cannot establish the requested before-handoff phase.
        try #require(abs(reopened.modelOffset - offsetBeforeCollapse) < 2, "Successor reading arrived after the model viewport moved")
        let presentationOffset = try #require(reopened.presentationOffset)
        try #require(abs(presentationOffset - offsetBeforeCollapse) < 2, "Successor reading arrived after the visible viewport moved")
        try #require(scenario.model.entries[0].collapse.isCollapsed == false)
        let finalHeaders = try scenario.visibleHeaders(in: scroll)
        try #require(finalHeaders.count == 1, "Initial source header=\(sourceHeader), final headers=\(finalHeaders)")
        let reopenedHeader = try #require(finalHeaders.first)
        let finalPresentation = try #require(scroll.layer.presentation())
        let finalViewport = finalPresentation.convert(finalPresentation.bounds, to: nil)
        let reopenedPosition = CGPoint(
            x: reopenedHeader.frame.minX - finalViewport.minX,
            y: reopenedHeader.frame.minY - finalViewport.minY
        )
        let reopenedHeaderImage = try scenario.imageData(in: reopenedHeader.frame)
        let diagnostic = Comment(rawValue: "collapse=\(collapse), sourceHeader=\(sourceHeader), reopenedHeader=\(reopenedHeader), sourcePosition=\(sourcePosition), reopenedPosition=\(reopenedPosition), reopen=\(reopened)")
        if reopenedHeaderImage != sourceHeaderImage {
            Attachment.record(Array(sourceHeaderImage), named: "source-header-\(collapse).png")
            Attachment.record(Array(reopenedHeaderImage), named: "reopened-header-\(collapse).png")
        }
        #expect(reopenedHeaderImage == sourceHeaderImage, diagnostic)
        #expect(
            abs(reopenedPosition.x - sourcePosition.x) < 2 && abs(reopenedPosition.y - sourcePosition.y) < 2,
            diagnostic
        )
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

        var horizontalScroll: UIScrollView? {
            guard let root = verticalScroll else { return nil }
            var remaining: [UIView] = [root]
            while let view = remaining.popLast() {
                if let scroll = view as? UIScrollView,
                   scroll.bounds.height > 0,
                   scroll.contentSize.height > 0,
                   abs(scroll.contentSize.height - scroll.bounds.height) < 2 {
                    return scroll
                }
                remaining.append(contentsOf: view.subviews)
            }
            return nil
        }

        init(
            entries: [ContinuousDiffEntry],
            jumpTarget: FileID? = nil,
            pointSize: CGFloat = SnapshotLayout.iPhoneLight.codePointSize,
            highlighted: [FileID: HighlightedFile] = [:]
        ) throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            previousWindow = scene.windows.first(where: \.isKeyWindow)
            model = CollapseHarness(entries: entries, jumpTarget: jumpTarget)
            controller = UIHostingController(rootView: CollapseHarnessView(model: model, pointSize: pointSize, highlighted: highlighted))
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = controller
            window.makeKeyAndVisible()
        }

        func close() {
            model.sourceReopenOnRead = nil
            window.isHidden = true
            previousWindow?.makeKey()
        }

        func visibleHeaders(in scroll: UIScrollView) throws -> [HeaderPresentation] {
            let probe = ViewportMotionProbe(scroll: scroll)
            probe.start()
            defer { probe.stop() }
            let sample = try #require(probe.samples.last)
            let presentation = try #require(scroll.layer.presentation())
            let viewport = presentation.convert(presentation.bounds, to: nil)
            return sample.headerFrames.filter { $0.opacity > 0.99 && $0.frame.intersects(viewport) }
        }

        func imageData(in frame: CGRect) throws -> Data {
            try #require(window.bounds.contains(frame), "Capture is outside the fixture window: \(frame)")
            var rendered = false
            let data = UIGraphicsImageRenderer(bounds: frame).pngData { _ in
                rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try #require(rendered, "Fixture window rendering did not complete")
            return data
        }

        func settleJump() async throws {
            let root = try #require(controller.viewIfLoaded)
            let observation = RenderSettlementProbe(root: root)
            observation.start()
            defer { observation.stop() }
            let deadline = CACurrentMediaTime() + 3
            while (model.jumpTarget != nil || observation.quietFrames < 5), CACurrentMediaTime() < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            try #require(model.jumpTarget == nil, "Requested file selection did not finish")
            try #require(observation.quietFrames >= 5, "Native file selection did not settle")
        }

        func settleSourceReopen() async throws {
            let root = try #require(controller.viewIfLoaded)
            let observation = RenderSettlementProbe(root: root)
            observation.start()
            defer { observation.stop() }
            let deadline = CACurrentMediaTime() + 3
            while (model.sourceReopenObservation == nil || observation.quietFrames < 5), CACurrentMediaTime() < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            try #require(model.sourceReopenObservation != nil, "Successor reading did not expose the reopen phase")
            try #require(observation.quietFrames >= 5, "Native source reopen did not settle")
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

enum DiffMotionFixture: Sendable {
    case plain
    case wordDiff
    case unsegmentedWordDiff
    case wordDiffOutgoing
    case wordDiffSuccessor
}

enum NativeHunkWidthFixture: CaseIterable, Hashable, Sendable {
    case printableAscii
    case tabs
    case cjkRanking
    case combiningAndAmbiguous
    case emoji
    case controls
    case highlightFallback
    case conflictWeight
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
               (scroll.bounds.height > 100 && scroll.contentSize.height > scroll.bounds.height
                    || scroll.bounds.width > 0 && scroll.contentSize.width > scroll.bounds.width),
               let presentation = scroll.layer.presentation() {
                scrollGeometry[ObjectIdentifier(scroll)] = ScrollRendering(
                    bounds: scroll.bounds,
                    presentationBounds: presentation.bounds,
                    contentSize: scroll.contentSize,
                    adjustedInset: scroll.adjustedContentInset
                )
                nativeScrolling = nativeScrolling || scroll.isScrollAnimating
                    || abs(presentation.bounds.minX - scroll.bounds.minX) >= 0.1
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
    let headerCandidates: [HeaderCandidate]
    let headerFrames: [HeaderPresentation]
    let nativeClocks: [NativeLayerClock]
}

private struct NativeLayerClock {
    let localTime: CFTimeInterval
    let modelFrame: CGRect
    let timing: NativeLayerTiming
}

private struct NativeLayerTiming: Equatable {
    let identity: ObjectIdentifier
    let type: String
    let beginTime: CFTimeInterval
    let duration: CFTimeInterval
    let timeOffset: CFTimeInterval
    let speed: Float
    let animationCount: Int
    let animations: [NativeAnimationTiming]
}

private struct NativeAnimationTiming: Equatable {
    let path: String
    let type: String
    let keyPath: String?
    let beginTime: CFTimeInterval
    let duration: CFTimeInterval
    let timeOffset: CFTimeInterval
    let speed: Float
    let childCount: Int
}

private struct HeaderCandidate {
    let header: HeaderPresentation
    let ancestorIdentities: [ObjectIdentifier]
}

private struct HeaderPresentation {
    let identity: ObjectIdentifier
    let frame: CGRect
    let opacity: Float
}

private struct NestedHeaderGeometry {
    let sampleIndex: Int
    let retained: HeaderPresentation?
    let descendant: HeaderPresentation
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
        var headerCandidates: [HeaderCandidate] = []
        var capturedClocks: Set<ObjectIdentifier> = []
        var nativeClocks: [NativeLayerClock] = []
        captureClock(scroll.layer, at: callbackStarted, required: true, visited: &capturedClocks, into: &nativeClocks)
        while let layer = remaining.popLast() {
            if abs(layer.bounds.height - DiffFileHeader.height) < 0.5,
               abs(layer.bounds.width - scroll.bounds.width) < 2,
               let drawn = layer.presentation() {
                captureClock(layer, at: callbackStarted, required: true, visited: &capturedClocks, into: &nativeClocks)
                var opacity = drawn.opacity
                var ancestor = drawn.superlayer
                while let parent = ancestor {
                    opacity *= parent.opacity
                    if parent.isHidden { opacity = 0 }
                    ancestor = parent.superlayer
                }
                var ancestorIdentities: [ObjectIdentifier] = []
                var modelAncestor = layer.superlayer
                while let parent = modelAncestor {
                    ancestorIdentities.append(ObjectIdentifier(parent))
                    captureClock(parent, at: callbackStarted, required: false, visited: &capturedClocks, into: &nativeClocks)
                    modelAncestor = parent.superlayer
                }
                headerCandidates.append(HeaderCandidate(
                    header: HeaderPresentation(
                        identity: ObjectIdentifier(layer),
                        frame: drawn.convert(drawn.bounds, to: nil),
                        opacity: drawn.isHidden ? 0 : opacity
                    ),
                    ancestorIdentities: ancestorIdentities
                ))
            }
            remaining.append(contentsOf: layer.sublayers ?? [])
        }
        let candidateIdentities = Set(headerCandidates.map(\.header.identity))
        // A header-sized wrapper and its header-sized descendant are one physical geometry unit.
        // Keep the outermost candidate; unrelated siblings remain separate and fail the count guard.
        let headerFrames = headerCandidates.filter { candidate in
            candidate.ancestorIdentities.contains { candidateIdentities.contains($0) } == false
        }.map(\.header)
        samples.append(ViewportMotionSample(
            elapsed: timestamp - startedAt,
            callbackElapsed: callbackStarted - startedAt,
            captureDuration: CACurrentMediaTime() - callbackStarted,
            modelOffset: scroll.contentOffset.y,
            presentationOffset: presentation.bounds.origin.y,
            headerCandidates: headerCandidates,
            headerFrames: headerFrames,
            nativeClocks: nativeClocks
        ))
    }

    private func captureClock(
        _ layer: CALayer,
        at hostTime: CFTimeInterval,
        required: Bool,
        visited: inout Set<ObjectIdentifier>,
        into clocks: inout [NativeLayerClock]
    ) {
        guard visited.insert(ObjectIdentifier(layer)).inserted else { return }
        let keys = layer.animationKeys() ?? []
        guard required || keys.isEmpty == false || layer.speed != 1 || layer.timeOffset != 0 || layer.beginTime != 0 else { return }
        var animations: [NativeAnimationTiming] = []
        var pending = keys.prefix(4).compactMap { key -> (path: String, animation: CAAnimation, depth: Int)? in
            guard let animation = layer.animation(forKey: key) else { return nil }
            return (path: key, animation: animation, depth: 0)
        }
        while let item = pending.popLast() {
            let children = (item.animation as? CAAnimationGroup)?.animations ?? []
            animations.append(NativeAnimationTiming(
                path: item.path,
                type: String(describing: type(of: item.animation)),
                keyPath: (item.animation as? CAPropertyAnimation)?.keyPath,
                beginTime: item.animation.beginTime,
                duration: item.animation.duration,
                timeOffset: item.animation.timeOffset,
                speed: item.animation.speed,
                childCount: children.count
            ))
            if item.depth < 2 {
                pending.append(contentsOf: children.prefix(4).enumerated().map { index, child in
                    (path: "\(item.path)/\(index)", animation: child, depth: item.depth + 1)
                })
            }
        }
        clocks.append(NativeLayerClock(
            localTime: layer.convertTime(hostTime, from: nil),
            modelFrame: layer.convert(layer.bounds, to: nil),
            timing: NativeLayerTiming(
                identity: ObjectIdentifier(layer),
                type: String(describing: type(of: layer)),
                beginTime: layer.beginTime,
                duration: layer.duration,
                timeOffset: layer.timeOffset,
                speed: layer.speed,
                animationCount: keys.count,
                animations: animations
            )
        ))
    }
}

@MainActor
private func aRenderedFile(
    path: String,
    lineCount: Int,
    widestLineAt: Int? = nil,
    repeatedLine: String? = nil
) -> ContinuousDiffEntry {
    let lines = (1...lineCount).map { (number: Int) in
        let text = widestLineAt == number ? String(repeating: "x", count: 120) : repeatedLine ?? "let value\(number) = \(number)"
        return DiffLine(
            kind: .addition,
            oldNumber: nil,
            newNumber: number,
            text: text,
            displayColumns: widestLineAt == number || repeatedLine != nil ? text.count : 20,
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
private func aRenderedWordDiffFile(path: String, segmented: Bool = true) -> ContinuousDiffEntry {
    // Native word-diff layout for a generated array changing sixteen values on each line.
    // The deletion/addition pairs carry real text and segments rather than timing work in the probe.
    let lines = (1...160).flatMap { number -> [DiffLine] in
        let prefix = WordSegment(text: "let values\(number) = [", isChanged: false)
        let oldSegments = [prefix] + (0..<16).flatMap { value in
            [
                WordSegment(text: "oldValue\(value)", isChanged: true),
                WordSegment(text: value == 15 ? "]" : ", ", isChanged: false)
            ]
        }
        let newSegments = [prefix] + (0..<16).flatMap { value in
            [
                WordSegment(text: "newValue\(value)", isChanged: true),
                WordSegment(text: value == 15 ? "]" : ", ", isChanged: false)
            ]
        }
        let oldText = oldSegments.map(\.text).joined()
        let newText = newSegments.map(\.text).joined()
        return [
            DiffLine(
                kind: .deletion,
                oldNumber: number,
                newNumber: nil,
                text: oldText,
                displayColumns: oldText.count,
                segments: segmented ? oldSegments : nil
            ),
            DiffLine(
                kind: .addition,
                oldNumber: nil,
                newNumber: number,
                text: newText,
                displayColumns: newText.count,
                segments: segmented ? newSegments : nil
            )
        ]
    }
    return .ready(FileDiff(
        file: aChangedFile(
            path: path,
            status: .modified,
            insertions: 160,
            deletions: 160,
            estimatedLineCount: lines.count
        ),
        hunks: [Hunk(
            index: 0,
            oldStart: 1,
            oldCount: 160,
            newStart: 1,
            newCount: 160,
            sectionHeading: nil,
            lines: lines
        )],
        oldLineCount: 160,
        newLineCount: 160,
        isTruncated: false,
        truncationReason: nil
    ))
}

@MainActor
@Observable
private final class CollapseHarness {
    var entries: [ContinuousDiffEntry]
    var jumpTarget: FileID?
    var readingPositions: Set<Int> = []
    var sourceReopenOnRead: SourceReopenOnRead?
    var sourceReopenObservation: SourceReopenObservation?

    init(entries: [ContinuousDiffEntry], jumpTarget: FileID?) {
        self.entries = entries
        self.jumpTarget = jumpTarget
    }

    func setViewed(_ isViewed: Bool, fileId: FileID) {
        entries = entries.map { $0.id == fileId ? $0.viewed(isViewed) : $0 }
    }

    func setOpen(_ isOpen: Bool, fileId: FileID) {
        entries = entries.map { $0.id == fileId ? $0.opened(isOpen) : $0 }
    }

    func jumped() {
        jumpTarget = nil
    }

    func reading(_ position: Int) {
        readingPositions.insert(position)
        guard let trigger = sourceReopenOnRead, trigger.position == position else { return }
        sourceReopenOnRead = nil
        sourceReopenObservation = SourceReopenObservation(
            sourceWasCollapsed: entries.first { $0.id == trigger.sourceId }?.collapse.isCollapsed == true,
            modelOffset: trigger.scroll.contentOffset.y,
            presentationOffset: trigger.scroll.layer.presentation()?.bounds.minY
        )
        switch trigger.collapse {
        case .viewed: setViewed(false, fileId: trigger.sourceId)
        case .manual: setOpen(true, fileId: trigger.sourceId)
        }
    }
}

private struct SourceReopenOnRead {
    let position: Int
    let sourceId: FileID
    let collapse: PinnedFileCollapse
    let scroll: UIScrollView
}

private struct SourceReopenObservation {
    let sourceWasCollapsed: Bool
    let modelOffset: CGFloat
    let presentationOffset: CGFloat?
}

@MainActor
private struct CollapseHarnessView: View {
    let model: CollapseHarness
    let pointSize: CGFloat
    let highlighted: [FileID: HighlightedFile]

    var body: some View {
        NavigationStack {
            ContinuousDiffView(
                state: .reading(model.entries),
                logCopyState: .ready,
                pointSize: pointSize,
                jumpTarget: model.jumpTarget,
                highlighted: highlighted,
                isWaitingLong: false,
                onReading: model.reading,
                onRereading: { _ in },
                onJumped: model.jumped,
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
