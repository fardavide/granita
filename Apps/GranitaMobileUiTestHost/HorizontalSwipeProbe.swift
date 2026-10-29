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
    private let scrollCandidates = ProbeValueLabel("scrollCandidates")
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
    private var ambiguousVertical: ObjectIdentifier?
    private var ambiguousCandidates: Set<ObjectIdentifier> = []
    private var previousAmbiguousGeometry: [NativeCandidateGeometry] = []
    private var ambiguityFrames = 0
    private var ambiguityReport = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        let stack = UIStackView(arrangedSubviews: [
            status, verticalDepth, firstFileEnd, verticalPosition, horizontalTravel, verticalDrift, panFrames, sampleCount, missingFrames, codeChanged,
            scrollCandidates
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
        var allScrolls: [UIScrollView] = []
        var verticals: [UIScrollView] = []
        while let view = remaining.popLast() {
            if let scroll = view as? UIScrollView {
                allScrolls.append(scroll)
            }
            if let scroll = view as? UIScrollView, scroll.bounds.height > 100,
               scroll.contentSize.height > scroll.bounds.height {
                verticals.append(scroll)
            }
            remaining.append(contentsOf: view.subviews)
        }
        guard verticals.count == 1, let vertical = verticals.first, let presentation = vertical.layer.presentation() else {
            ambiguousVertical = nil
            ambiguousCandidates = []
            previousAmbiguousGeometry = []
            ambiguityFrames = 0
            ambiguityReport = ""
            scrollCandidates.set("verticals=\(verticals.count); all=\(allScrolls.map(scrollDescription).joined(separator: " | "))")
            return nil
        }
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
               viewport.contains(gesturePoint),
               isVisible(scroll, at: gesturePoint) {
                horizontals.append(scroll)
            }
            remaining.append(contentsOf: view.subviews)
        }
        guard horizontals.count == 1, let horizontal = horizontals.first else {
            if horizontals.count > 1 {
                let identities = Set(horizontals.map { ObjectIdentifier($0) })
                if ambiguousVertical != ObjectIdentifier(vertical) || ambiguousCandidates != identities {
                    ambiguousVertical = ObjectIdentifier(vertical)
                    ambiguousCandidates = identities
                    previousAmbiguousGeometry = []
                    ambiguityFrames = 0
                    ambiguityReport = "verticals=1; horizontals=\(horizontals.count); point=\(gesturePoint); viewport=\(viewport); allCount=\(allScrolls.count); initial=\(allScrolls.prefix(8).map(scrollDescription).joined(separator: " | "))"
                }
                if ambiguityFrames < 30 {
                    let nativeGeometry = ([vertical] + horizontals).map { scroll in
                        let drawn = scroll.layer.presentation()
                        return NativeCandidateGeometry(
                            identity: ObjectIdentifier(scroll),
                            bounds: scroll.bounds,
                            contentSize: scroll.contentSize,
                            presentationBounds: drawn?.bounds,
                            presentationFrame: drawn.map { $0.convert($0.bounds, to: nil) },
                            isHidden: scroll.isHidden
                        )
                    }
                    ambiguityFrames = nativeGeometry == previousAmbiguousGeometry ? ambiguityFrames + 1 : 1
                    previousAmbiguousGeometry = nativeGeometry
                    if ambiguityFrames == 30 {
                        // Capture once per persistent set after geometry stabilizes; keep settlement unchanged.
                        ambiguityReport = "verticals=1; horizontals=\(horizontals.count); point=\(gesturePoint); viewport=\(viewport); allCount=\(allScrolls.count); all=\(allScrolls.prefix(8).map(scrollDescription).joined(separator: " | "))\n"
                            + duplicateCandidateReport(horizontals, in: window, at: gesturePoint)
                    }
                }
                scrollCandidates.set(ambiguityReport)
                return nil
            } else {
                ambiguousVertical = nil
                ambiguousCandidates = []
                previousAmbiguousGeometry = []
                ambiguityFrames = 0
                ambiguityReport = ""
            }
            scrollCandidates.set("verticals=1; horizontals=\(horizontals.count); point=\(gesturePoint); viewport=\(viewport); all=\(allScrolls.map(scrollDescription).joined(separator: " | "))")
            return nil
        }
        ambiguousVertical = nil
        ambiguousCandidates = []
        previousAmbiguousGeometry = []
        ambiguityFrames = 0
        ambiguityReport = ""
        scrollCandidates.set("verticals=1; horizontals=1")
        return (vertical, horizontal)
    }

    private func isVisible(_ scroll: UIScrollView, at point: CGPoint) -> Bool {
        var ancestor: CALayer? = scroll.layer
        while let layer = ancestor {
            if let drawn = layer.presentation() {
                if drawn.isHidden || drawn.opacity == 0 { return false }
                if drawn.masksToBounds, drawn.bounds.contains(drawn.convert(point, from: nil)) == false {
                    return false
                }
            }
            // Missing presentation geometry leaves visibility unknown, so the candidate remains.
            ancestor = layer.superlayer
        }
        return true
    }

    private func scrollDescription(_ scroll: UIScrollView) -> String {
        let frame = scroll.layer.presentation().map { $0.convert($0.bounds, to: nil) }
        return "\(ObjectIdentifier(scroll)) size=\(scroll.contentSize) bounds=\(scroll.bounds) overflowY=\(scroll.contentSize.height - scroll.bounds.height) presentation=\(String(describing: frame)) hidden=\(scroll.isHidden)"
    }

    private func duplicateCandidateReport(_ scrolls: [UIScrollView], in window: UIWindow, at point: CGPoint) -> String {
        let reportedScrolls = Array(scrolls.prefix(4))
        var viewChains: [[UIView]] = []
        var layerChains: [[CALayer]] = []
        for scroll in reportedScrolls {
            var views: [UIView] = []
            var nextView: UIView? = scroll
            while let view = nextView {
                views.append(view)
                nextView = view.superview
            }
            viewChains.append(views)
            var layers: [CALayer] = []
            var nextLayer: CALayer? = scroll.layer
            while let layer = nextLayer {
                layers.append(layer)
                nextLayer = layer.superlayer
            }
            layerChains.append(layers)
        }
        let commonView = viewChains.first?.first { ancestor in
            viewChains.dropFirst().allSatisfy { chain in chain.contains { $0 === ancestor } }
        }
        let commonLayer = layerChains.first?.first { ancestor in
            layerChains.dropFirst().allSatisfy { chain in chain.contains { $0 === ancestor } }
        }
        let hit = window.hitTest(point, with: nil)
        var hitChain: [String] = []
        var nextHit = hit
        while let view = nextHit {
            hitChain.append("\(ObjectIdentifier(view)):\(String(reflecting: type(of: view)))")
            nextHit = view.superview
        }
        var lines = [
            "Persistent ambiguity capture after 30 unchanged native-geometry frames; timestamp=\(CACurrentMediaTime()); candidates=\(scrolls.count); reporting=\(reportedScrolls.count); ancestorDetailLimit=16; characterLimit=48000",
            "viewLca=\(String(describing: commonView.map { ObjectIdentifier($0) })); layerLca=\(String(describing: commonLayer.map { ObjectIdentifier($0) }))",
            "windowHitTest=\(hitChain.joined(separator: " -> "))",
            "Frames use convert(..., to: nil), matching the existing candidate predicate. Clip/mask envelopes are rectangular diagnostics, not proof of rendered alpha or visibility."
        ]
        for (index, scroll) in reportedScrolls.enumerated() {
            let ownsHit = hit.map { $0 === scroll || $0.isDescendant(of: scroll) } ?? false
            let hitIsAncestor = hit.map { scroll.isDescendant(of: $0) } ?? false
            lines.append("candidate[\(index)]=\(ObjectIdentifier(scroll)); window=\(String(describing: scroll.window.map { ObjectIdentifier($0) })); sameWindow=\(scroll.window === window); ownsHit=\(ownsHit); hitIsAncestor=\(hitIsAncestor); scrollEnabled=\(scroll.isScrollEnabled)")
            var effectiveViewAlpha: CGFloat = 1
            var anyViewHidden = false
            for (depth, view) in viewChains[index].enumerated() {
                effectiveViewAlpha *= view.alpha
                anyViewHidden = anyViewHidden || view.isHidden
                if depth < 16 {
                    let drawnFrame = view.layer.presentation().map { $0.convert($0.bounds, to: nil) }
                    lines.append(" view=\(ObjectIdentifier(view)):\(String(reflecting: type(of: view))); layer=\(ObjectIdentifier(view.layer)); bounds=\(view.bounds); modelFrame=\(view.convert(view.bounds, to: nil)); presentationFrame=\(String(describing: drawnFrame)); alpha=\(view.alpha); hidden=\(view.isHidden); clips=\(view.clipsToBounds); userInteraction=\(view.isUserInteractionEnabled); cumulativeViewAlpha=\(effectiveViewAlpha); ancestorHidden=\(anyViewHidden)")
                }
            }
            var effectiveModelOpacity: Float = 1
            var effectivePresentationOpacity: Float = 1
            var anyModelHidden = false
            var anyPresentationHidden = false
            var presentationComplete = true
            var modelClipEnvelope = scroll.layer.convert(scroll.layer.bounds, to: nil)
            var presentationClipEnvelope = scroll.layer.presentation().map { $0.convert($0.bounds, to: nil) } ?? .null
            var modelMaskFrameEnvelope = modelClipEnvelope
            var presentationMaskFrameEnvelope = presentationClipEnvelope
            for (depth, layer) in layerChains[index].enumerated() {
                let drawn = layer.presentation()
                effectiveModelOpacity *= layer.opacity
                anyModelHidden = anyModelHidden || layer.isHidden
                if layer.masksToBounds {
                    modelClipEnvelope = modelClipEnvelope.intersection(layer.convert(layer.bounds, to: nil))
                }
                if let drawn {
                    effectivePresentationOpacity *= drawn.opacity
                    anyPresentationHidden = anyPresentationHidden || drawn.isHidden
                    if drawn.masksToBounds {
                        presentationClipEnvelope = presentationClipEnvelope.intersection(drawn.convert(drawn.bounds, to: nil))
                    }
                } else {
                    presentationComplete = false
                }
                if depth < 16 {
                    lines.append(" layer=\(ObjectIdentifier(layer)):\(String(reflecting: type(of: layer))); presentation=\(String(describing: drawn.map { ObjectIdentifier($0) })); bounds=\(layer.bounds); modelFrame=\(layer.convert(layer.bounds, to: nil)); presentationBounds=\(String(describing: drawn?.bounds)); presentationFrame=\(String(describing: drawn.map { $0.convert($0.bounds, to: nil) })); opacity=\(layer.opacity)/\(String(describing: drawn?.opacity)); hidden=\(layer.isHidden)/\(String(describing: drawn?.isHidden)); masksToBounds=\(layer.masksToBounds)/\(String(describing: drawn?.masksToBounds)); animations=\(layer.animationKeys() ?? [])")
                }
                if let mask = layer.mask {
                    // A mask's frame is in its owner's coordinates even though it is not a sublayer.
                    let frame = layer.convert(mask.frame, to: nil)
                    modelMaskFrameEnvelope = modelMaskFrameEnvelope.intersection(frame)
                    if depth < 16 {
                        lines.append("  modelMask=\(ObjectIdentifier(mask)):\(String(reflecting: type(of: mask))); bounds=\(mask.bounds); frameInOwner=\(mask.frame); globalFrameEnvelope=\(frame); opacity=\(mask.opacity); hidden=\(mask.isHidden); transform=\(mask.transform); pathBounds=\(String(describing: (mask as? CAShapeLayer)?.path?.boundingBoxOfPath)); sublayers=\(mask.sublayers?.count ?? 0)")
                    }
                }
                if let drawn, let mask = drawn.mask {
                    let frame = drawn.convert(mask.frame, to: nil)
                    presentationMaskFrameEnvelope = presentationMaskFrameEnvelope.intersection(frame)
                    if depth < 16 {
                        lines.append("  presentationMask=\(ObjectIdentifier(mask)):\(String(reflecting: type(of: mask))); bounds=\(mask.bounds); frameInOwner=\(mask.frame); globalFrameEnvelope=\(frame); opacity=\(mask.opacity); hidden=\(mask.isHidden); transform=\(mask.transform); pathBounds=\(String(describing: (mask as? CAShapeLayer)?.path?.boundingBoxOfPath)); sublayers=\(mask.sublayers?.count ?? 0)")
                    }
                } else if layer.mask != nil, depth < 16 {
                    lines.append("  presentationMask=unavailable; no model-to-presentation substitution")
                }
            }
            lines.append(" summary[\(index)]: viewAncestors=\(viewChains[index].count); layerAncestors=\(layerChains[index].count); cumulativeValuesCoverFullChains=true; viewAlpha=\(effectiveViewAlpha); viewHidden=\(anyViewHidden); modelOpacity=\(effectiveModelOpacity); presentationOpacity=\(effectivePresentationOpacity); modelHidden=\(anyModelHidden); presentationHidden=\(anyPresentationHidden); presentationChainComplete=\(presentationComplete); modelClipEnvelope=\(modelClipEnvelope); presentationClipEnvelope=\(presentationClipEnvelope); modelClipContainsPoint=\(modelClipEnvelope.contains(point)); presentationClipContainsPoint=\(presentationClipEnvelope.contains(point)); modelMaskFrameIntersection=\(modelMaskFrameEnvelope.intersection(modelClipEnvelope)); presentationMaskFrameIntersection=\(presentationMaskFrameEnvelope.intersection(presentationClipEnvelope))")
        }
        let report = lines.joined(separator: "\n")
        return report.count <= 48_000 ? report : String(report.prefix(48_000)) + "\n[ancestry report truncated]"
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

private struct NativeCandidateGeometry: Equatable {
    let identity: ObjectIdentifier
    let bounds: CGRect
    let contentSize: CGSize
    let presentationBounds: CGRect?
    let presentationFrame: CGRect?
    let isHidden: Bool
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
