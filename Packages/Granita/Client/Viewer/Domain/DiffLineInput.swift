// Match SwiftUI's geometry overlay when Release optimization imports this module's function bodies.
import CoreGraphics
import Foundation

import CoreReviewDomain

/// Transient finger state, separate from the comment draft that survives a released hold.
public struct DiffLineInput {

    public private(set) var isPressing: Bool
    public private(set) var holds: Int
    private var pressX: CGFloat

    public init() {
        isPressing = false
        holds = 0
        pressX = 0
    }

    public func tapped(
        at point: CGPoint,
        targeting: DiffLineTargeting,
        onTap: (DiffLinePosition) -> Void
    ) {
        guard targeting.acceptsTargeting, isPressing == false,
              let line = targeting.line(at: point) else { return }
        onTap(line)
    }

    public mutating func began(
        at point: CGPoint,
        targeting: DiffLineTargeting,
        onHold: (DiffLinePosition) -> Void,
        onPressingChanged: (Bool) -> Void
    ) {
        guard targeting.acceptsTargeting, let line = targeting.line(at: point) else { return }
        pressX = point.x
        isPressing = true
        holds += 1
        onHold(line)
        onPressingChanged(true)
    }

    public func dragged(
        to point: CGPoint,
        targeting: DiffLineTargeting,
        onDrag: (DiffLinePosition) -> Void
    ) {
        guard targeting.acceptsTargeting, isPressing,
              let line = targeting.line(at: CGPoint(x: pressX, y: point.y)) else { return }
        onDrag(line)
    }

    public mutating func finished(onPressingChanged: (Bool) -> Void, onEnd: () -> Void) {
        guard isPressing else { return }
        isPressing = false
        onPressingChanged(false)
        onEnd()
    }

    public mutating func cancelled(onPressingChanged: (Bool) -> Void) {
        guard isPressing else { return }
        isPressing = false
        onPressingChanged(false)
    }
}
