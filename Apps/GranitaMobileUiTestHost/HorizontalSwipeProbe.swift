import QuartzCore
import UIKit

/// Reads public native geometry. Only the UI runner supplies scrolling input.
@MainActor
final class HorizontalSwipeProbe: UIView {
    private let status = ProbeValueLabel("status")
    private let verticalDepth = ProbeValueLabel("verticalDepth")
    private let firstFileEnd = ProbeValueLabel("firstFileEnd")
    private let verticalPosition = ProbeValueLabel("verticalPosition")
    private let horizontalTravel = ProbeValueLabel("horizontalTravel")
    private let verticalDrift = ProbeValueLabel("verticalDrift")
    private let panFrames = ProbeValueLabel("panFrames")
    private let sampleCount = ProbeValueLabel("sampleCount")
    private let missingFrames = ProbeValueLabel("missingFrames")
    private let codeChanged = ProbeValueLabel("codeChanged")
    private var displayLink: CADisplayLink?
    private var previous: ScrollGeometry?
    private var quietFrames = 0
    private var baseline: ScrollGeometry?
    private var initialImage: Data?
    private var crop: CGRect?
    private var maximumVerticalDrift: CGFloat = 0
    private var maximumHorizontalTravel: CGFloat = 0
    private var observedPanFrames = 0
    private var observedFrames = 0
    private var missingGeometryFrames = 0
    private var observing = false
    private var initialFileEndDepth: CGFloat?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        let stack = UIStackView(arrangedSubviews: [
            status, verticalDepth, firstFileEnd, verticalPosition, horizontalTravel, verticalDrift, panFrames, sampleCount, missingFrames, codeChanged
        ])
        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        status.set("waiting")
    }

    required init?(coder: NSCoder) { return nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        displayLink?.invalidate()
        guard window != nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(observeFrame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func arm() {
        guard quietFrames >= 5, let scrolls = visibleScrolls(), let geometry = geometry(of: scrolls) else {
            status.set("not settled")
            return
        }
        let rectangle = CGRect(x: geometry.codeFrame.minX + 8, y: geometry.viewport.minY + 100, width: 200, height: 90)
        guard geometry.viewport.contains(rectangle), geometry.codeFrame.contains(rectangle), let image = imageData(in: rectangle) else {
            status.set("capture unavailable")
            return
        }
        baseline = geometry
        initialImage = image
        crop = rectangle
        maximumVerticalDrift = 0
        maximumHorizontalTravel = 0
        observedPanFrames = 0
        observedFrames = 0
        missingGeometryFrames = 0
        missingFrames.set("0")
        observing = true
        codeChanged.set("pending")
        status.set("armed")
    }

    @objc private func observeFrame() {
        guard let scrolls = visibleScrolls(), let current = geometry(of: scrolls) else {
            if observing {
                missingGeometryFrames += 1
                missingFrames.set(String(missingGeometryFrames))
            }
            status.set("waiting")
            quietFrames = 0
            return
        }
        verticalDepth.set(String(Double(current.verticalModel + scrolls.vertical.adjustedContentInset.top)))
        verticalPosition.set(String(Double(current.verticalPresentation)))
        quietFrames = current == previous && current.moving == false ? quietFrames + 1 : 0
        previous = current
        if initialFileEndDepth == nil, quietFrames >= 5,
           abs(current.verticalModel + scrolls.vertical.adjustedContentInset.top) < 2 {
            // The gesture point may already be over another file. Measure the topmost hunk
            // independently while the list is still at its initial top.
            var remaining: [UIView] = [scrolls.vertical]
            var firstCodeFrame: CGRect?
            while let view = remaining.popLast() {
                if let scroll = view as? UIScrollView, scroll.bounds.height > 0,
                   abs(scroll.contentSize.height - scroll.bounds.height) < 2,
                   let presentation = scroll.layer.presentation() {
                    let frame = presentation.convert(presentation.bounds, to: nil)
                    if firstCodeFrame == nil || frame.minY < (firstCodeFrame?.minY ?? .infinity) {
                        firstCodeFrame = frame
                    }
                }
                remaining.append(contentsOf: view.subviews)
            }
            guard let firstCodeFrame else {
                status.set("first hunk unavailable")
                return
            }
            let depth = current.verticalModel + scrolls.vertical.adjustedContentInset.top
            initialFileEndDepth = depth + firstCodeFrame.maxY - current.viewport.minY
            firstFileEnd.set(String(Double(depth + firstCodeFrame.maxY - current.viewport.minY)))
        }
        guard observing, let baseline else {
            if self.baseline == nil { status.set(quietFrames >= 5 ? "settled" : "moving") }
            return
        }
        observedFrames += 1
        maximumVerticalDrift = max(
            maximumVerticalDrift,
            max(abs(current.verticalModel - baseline.verticalModel), abs(current.verticalPresentation - baseline.verticalPresentation))
        )
        maximumHorizontalTravel = max(maximumHorizontalTravel, abs(current.horizontalPresentation - baseline.horizontalPresentation))
        if scrolls.horizontal.isDragging { observedPanFrames += 1 }
        horizontalTravel.set(String(Double(maximumHorizontalTravel)))
        verticalDrift.set(String(Double(maximumVerticalDrift)))
        panFrames.set(String(observedPanFrames))
        sampleCount.set(String(observedFrames))
        if observedPanFrames > 0 || maximumVerticalDrift >= 2,
           quietFrames >= 5, let crop, let initialImage {
            guard let finalImage = imageData(in: crop) else {
                status.set("capture unavailable")
                return
            }
            codeChanged.set(finalImage == initialImage ? "false" : "true")
            observing = false
            status.set("complete")
        }
    }

    private func visibleScrolls() -> (vertical: UIScrollView, horizontal: UIScrollView)? {
        guard let root = window?.rootViewController?.view else { return nil }
        var remaining = [root]
        var verticals: [UIScrollView] = []
        while let view = remaining.popLast() {
            if let scroll = view as? UIScrollView, scroll.bounds.height > 100,
               scroll.contentSize.height > scroll.bounds.height {
                verticals.append(scroll)
            }
            remaining.append(contentsOf: view.subviews)
        }
        guard verticals.count == 1, let vertical = verticals.first, let presentation = vertical.layer.presentation() else { return nil }
        let viewport = presentation.convert(presentation.bounds, to: nil)
        guard let window else { return nil }
        let gesturePoint = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
        remaining = [vertical]
        var horizontals: [UIScrollView] = []
        while let view = remaining.popLast() {
            if let scroll = view as? UIScrollView, scroll.bounds.height > 0,
               abs(scroll.contentSize.height - scroll.bounds.height) < 2,
               let presentation = scroll.layer.presentation(),
               presentation.convert(presentation.bounds, to: nil).contains(gesturePoint),
               viewport.contains(gesturePoint) {
                horizontals.append(scroll)
            }
            remaining.append(contentsOf: view.subviews)
        }
        guard horizontals.count == 1, let horizontal = horizontals.first else { return nil }
        return (vertical, horizontal)
    }

    private func geometry(of scrolls: (vertical: UIScrollView, horizontal: UIScrollView)) -> ScrollGeometry? {
        guard let vertical = scrolls.vertical.layer.presentation(), let horizontal = scrolls.horizontal.layer.presentation() else { return nil }
        return ScrollGeometry(
            verticalModel: scrolls.vertical.contentOffset.y, verticalPresentation: vertical.bounds.minY,
            horizontalModel: scrolls.horizontal.contentOffset.x, horizontalPresentation: horizontal.bounds.minX,
            verticalSize: scrolls.vertical.contentSize, horizontalSize: scrolls.horizontal.contentSize,
            viewport: vertical.convert(vertical.bounds, to: nil), codeFrame: horizontal.convert(horizontal.bounds, to: nil),
            moving: [scrolls.vertical, scrolls.horizontal].contains {
                $0.isDragging || $0.isDecelerating || $0.isScrollAnimating
                    || abs(($0.layer.presentation()?.bounds.minX ?? $0.bounds.minX) - $0.bounds.minX) >= 0.1
                    || abs(($0.layer.presentation()?.bounds.minY ?? $0.bounds.minY) - $0.bounds.minY) >= 0.1
            }
        )
    }

    private func imageData(in frame: CGRect) -> Data? {
        guard let window, window.bounds.contains(frame) else { return nil }
        var rendered = false
        let data = UIGraphicsImageRenderer(bounds: frame).pngData { _ in
            rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        return rendered ? data : nil
    }
}

private struct ScrollGeometry: Equatable {
    let verticalModel: CGFloat
    let verticalPresentation: CGFloat
    let horizontalModel: CGFloat
    let horizontalPresentation: CGFloat
    let verticalSize: CGSize
    let horizontalSize: CGSize
    let viewport: CGRect
    let codeFrame: CGRect
    let moving: Bool
}

@MainActor
private final class ProbeValueLabel: UILabel {
    init(_ name: String) {
        super.init(frame: .zero)
        font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        isAccessibilityElement = true
        accessibilityIdentifier = "swipe-probe.\(name)"
        accessibilityLabel = name
    }

    required init?(coder: NSCoder) { return nil }

    func set(_ value: String) {
        guard accessibilityValue != value else { return }
        accessibilityValue = value
        text = "\(accessibilityLabel ?? "metric"): \(value)"
    }
}
