#if canImport(UIKit)
import SwiftUI

import ClientViewerDomain
import CoreDiffDomain
import CoreReviewDomain

/// Native input wiring is measured by behavioral tests, independently of rendered states.
struct DiffLineSelection: ViewModifier {

    let diff: FileDiff
    let pointSize: CGFloat
    let isSplit: Bool
    let acceptsTargeting: Bool
    @Binding var hunkFrames: [Int: CGRect]
    let onTap: (DiffLinePosition) -> Void
    let onHold: (DiffLinePosition) -> Void
    let onDrag: (DiffLinePosition) -> Void
    let onEnd: () -> Void
    let onPressingChanged: (Bool) -> Void

    @State private var input = DiffLineInput()

    func body(content: Content) -> some View {
        content
            .gesture(DiffLineLongPress(
                isEnabled: acceptsTargeting,
                onBegan: {
                    input.began(at: $0, targeting: targeting, onHold: onHold, onPressingChanged: onPressingChanged)
                },
                onChanged: { input.dragged(to: $0, targeting: targeting, onDrag: onDrag) },
                onEnded: { input.finished(onPressingChanged: onPressingChanged, onEnd: onEnd) },
                onCancelled: { input.cancelled(onPressingChanged: onPressingChanged) }
            ))
            .simultaneousGesture(
                SpatialTapGesture().onEnded {
                    input.tapped(at: $0.location, targeting: targeting, onTap: onTap)
                },
                isEnabled: acceptsTargeting
            )
            .sensoryFeedback(.selection, trigger: input.holds)
            .onDisappear { input.cancelled(onPressingChanged: onPressingChanged) }
    }

    // Read measurements only when input arrives: a body dependency on frame writes disrupts motion.
    private var targeting: DiffLineTargeting {
        DiffLineTargeting(
            hunks: diff.hunks,
            frames: hunkFrames,
            pointSize: pointSize,
            rowHeight: DiffLineHeight.at(pointSize: pointSize),
            isSplit: isSplit,
            acceptsTargeting: acceptsTargeting
        )
    }
}
#endif
