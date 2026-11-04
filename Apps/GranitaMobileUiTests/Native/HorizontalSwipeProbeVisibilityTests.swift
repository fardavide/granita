import QuartzCore
import Testing
import UIKit

@testable import GranitaMobileUiTestHost

@Suite("Horizontal swipe probe visibility", .serialized)
@MainActor
struct HorizontalSwipeProbeVisibilityTests {

    @Test(arguments: [Occlusion.ancestorHidden, .ancestorClipped, .ancestorTransparent])
    private func `given an excluded horizontal subtree when observing native scrolls then only visible code competes`(
        occlusion: Occlusion
    ) async throws {
        // given
        let scenario = try Scenario(occlusion: occlusion)
        defer { scenario.close() }
        let status = try #require(scenario.label("swipe-probe.status"))
        let candidates = try #require(scenario.label("swipe-probe.scrollCandidates"))
        let presentationDeadline = CACurrentMediaTime() + 3
        while (scenario.visible.layer.presentation() == nil || scenario.excluded.layer.presentation() == nil),
              CACurrentMediaTime() < presentationDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        _ = try #require(scenario.visible.layer.presentation())
        _ = try #require(scenario.excluded.layer.presentation())

        // when
        let framesBefore = scenario.frames.count
        scenario.excludeCompetingSubtree()
        let settlementDeadline = CACurrentMediaTime() + 3
        while (scenario.frames.count < framesBefore + 6 || status.accessibilityValue != "settled"),
              CACurrentMediaTime() < settlementDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }

        // then
        // Establish the blind-spot fixture independently of the probe's candidate output.
        try #require(scenario.frames.count >= framesBefore + 6)
        let point = CGPoint(x: scenario.window.bounds.midX, y: scenario.window.bounds.midY)
        let visiblePresentation = try #require(scenario.visible.layer.presentation())
        let excludedPresentation = try #require(scenario.excluded.layer.presentation())
        try #require(visiblePresentation.convert(visiblePresentation.bounds, to: nil).contains(point))
        try #require(excludedPresentation.convert(excludedPresentation.bounds, to: nil).contains(point))
        try #require(scenario.excluded.isHidden == false)
        switch occlusion {
        case .ancestorHidden:
            try #require(scenario.occludingAncestor.isHidden)
        case .ancestorClipped:
            try #require(scenario.occludingAncestor.clipsToBounds)
            try #require(scenario.occludingAncestor.convert(scenario.occludingAncestor.bounds, to: nil).contains(point) == false)
        case .ancestorTransparent:
            try #require(scenario.occludingAncestor.alpha == 0)
            try #require(scenario.occludingAncestor.layer.presentation()?.opacity == 0)
            try #require(scenario.occludingAncestor.isHidden == false)
            try #require(scenario.occludingAncestor.clipsToBounds == false)
            try #require(scenario.excluded.alpha == 1)
        }
        let hit = try #require(scenario.window.hitTest(point, with: nil))
        try #require(hit === scenario.visible || hit.isDescendant(of: scenario.visible))
        let diagnostic = Comment(rawValue: candidates.accessibilityValue ?? "Probe candidate output unavailable")
        #expect(status.accessibilityValue == "settled", diagnostic)
        #expect(candidates.accessibilityValue == "verticals=1; horizontals=1", diagnostic)
    }

    private enum Occlusion: Sendable {
        case ancestorHidden
        case ancestorClipped
        case ancestorTransparent
    }

    @MainActor
    private struct Scenario {
        let window: UIWindow
        let previousWindow: UIWindow?
        let visible: UIScrollView
        let excluded: UIScrollView
        let occludingAncestor: UIView
        let probe: HorizontalSwipeProbe
        let frames: NativeFrameCounter
        let occlusion: Occlusion

        init(occlusion: Occlusion) throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            previousWindow = scene.windows.first(where: \.isKeyWindow)
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            let controller = UIViewController()
            window.rootViewController = controller
            let vertical = UIScrollView(frame: window.bounds)
            vertical.contentInsetAdjustmentBehavior = .never
            vertical.contentSize = CGSize(width: 390, height: 4_000)
            visible = UIScrollView(frame: CGRect(x: 50, y: 0, width: 300, height: 1_200))
            visible.contentSize = CGSize(width: 900, height: 1_200)
            excluded = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 1_200))
            excluded.contentSize = CGSize(width: 900, height: 1_200)
            occludingAncestor = UIView(frame: visible.frame)
            vertical.addSubview(visible)
            vertical.addSubview(occludingAncestor)
            occludingAncestor.addSubview(excluded)
            controller.view.addSubview(vertical)
            probe = HorizontalSwipeProbe(frame: CGRect(x: 0, y: 724, width: 390, height: 120))
            controller.view.addSubview(probe)
            self.occlusion = occlusion
            frames = NativeFrameCounter()
            window.makeKeyAndVisible()
            controller.view.layoutIfNeeded()
        }

        func excludeCompetingSubtree() {
            switch occlusion {
            case .ancestorHidden:
                occludingAncestor.isHidden = true
            case .ancestorClipped:
                occludingAncestor.frame.size.height = 80
                occludingAncestor.clipsToBounds = true
            case .ancestorTransparent:
                occludingAncestor.alpha = 0
            }
        }

        func label(_ identifier: String) -> UILabel? {
            var remaining: [UIView] = [probe]
            while let view = remaining.popLast() {
                if let label = view as? UILabel, label.accessibilityIdentifier == identifier {
                    return label
                }
                remaining.append(contentsOf: view.subviews)
            }
            return nil
        }

        func close() {
            frames.stop()
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKey()
        }
    }
}

@MainActor
private final class NativeFrameCounter: NSObject {
    private(set) var count = 0
    private lazy var displayLink = CADisplayLink(target: self, selector: #selector(observeFrame))

    override init() {
        super.init()
        displayLink.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink.invalidate()
    }

    @objc private func observeFrame() {
        count += 1
    }
}
