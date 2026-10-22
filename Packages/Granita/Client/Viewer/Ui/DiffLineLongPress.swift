#if canImport(UIKit)
import SwiftUI
import UIKit

/// A stationary hold reports its location when it begins, without requiring a drag to follow it.
struct DiffLineLongPress: UIGestureRecognizerRepresentable {

    let isEnabled: Bool
    let onBegan: (CGPoint) -> Void
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void
    let onCancelled: () -> Void

    init(
        isEnabled: Bool,
        onBegan: @escaping (CGPoint) -> Void,
        onChanged: @escaping (CGPoint) -> Void = { _ in },
        onEnded: @escaping () -> Void = {},
        onCancelled: @escaping () -> Void = {}
    ) {
        self.isEnabled = isEnabled
        self.onBegan = onBegan
        self.onChanged = onChanged
        self.onEnded = onEnded
        self.onCancelled = onCancelled
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.35
        recognizer.allowableMovement = 10
        recognizer.cancelsTouchesInView = false
        recognizer.isEnabled = isEnabled
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        if recognizer.state == .began {
            onBegan(context.converter.localLocation)
        }
        if recognizer.state == .changed || recognizer.state == .ended {
            onChanged(context.converter.localLocation)
        }
        if recognizer.state == .ended {
            onEnded()
        }
        if recognizer.state == .cancelled || recognizer.state == .failed {
            onCancelled()
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer is UIPanGestureRecognizer
        }
    }
}
#endif
