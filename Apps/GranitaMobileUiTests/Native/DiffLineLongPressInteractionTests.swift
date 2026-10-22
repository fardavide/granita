import Testing
import UIKit

@testable import ClientViewerUi

@Suite("Diff line long press interaction", .serialized)
@MainActor
struct DiffLineLongPressInteractionTests {

    @Test(arguments: [true, false])
    func `given a line hold when creating its native recognizer then line selection preserves touches and uses its coordinator`(
        isEnabled: Bool
    ) {
        // given
        let coordinator = DiffLineLongPress.Coordinator()

        // when
        let recognizer = DiffLineLongPress(isEnabled: isEnabled, onBegan: { _ in })
            .makeRecognizer(delegate: coordinator)

        // then
        #expect(recognizer.minimumPressDuration == 0.35)
        #expect(recognizer.allowableMovement == 10)
        #expect(recognizer.cancelsTouchesInView == false)
        #expect(recognizer.isEnabled == isEnabled)
        #expect(recognizer.delegate === coordinator)
    }

    @Test(arguments: [
        (UIGestureRecognizer.State.possible, [Event]()),
        (.began, [.began(CGPoint(x: 126, y: 237))]),
        (.changed, [.changed(CGPoint(x: 126, y: 237))]),
        (.ended, [.changed(CGPoint(x: 126, y: 237)), .ended]),
        (.cancelled, [.cancelled]),
        (.failed, [.cancelled])
    ])
    private func `given a line hold when recognition changes then callbacks describe its state in order`(
        state: UIGestureRecognizer.State,
        expectedEvents: [Event]
    ) {
        // given
        var events: [Event] = []
        let gesture = DiffLineLongPress(
            isEnabled: true,
            onBegan: { events.append(.began($0)) },
            onChanged: { events.append(.changed($0)) },
            onEnded: { events.append(.ended) },
            onCancelled: { events.append(.cancelled) }
        )

        // when
        gesture.handle(state: state, at: CGPoint(x: 126, y: 237))

        // then
        #expect(events == expectedEvents)
    }

    @Test(arguments: [(Companion.pan, true), (.tap, false), (.longPress, false)])
    private func `given a line hold when another recognizer competes then only panning may recognize simultaneously`(
        companion: Companion,
        expected: Bool
    ) {
        // given
        let coordinator = DiffLineLongPress.Coordinator()
        let other: UIGestureRecognizer
        switch companion {
        case .pan:
            other = UIPanGestureRecognizer()
        case .tap:
            other = UITapGestureRecognizer()
        case .longPress:
            other = UILongPressGestureRecognizer()
        }

        // when
        let mayRecognizeSimultaneously = coordinator.gestureRecognizer(
            UILongPressGestureRecognizer(),
            shouldRecognizeSimultaneouslyWith: other
        )

        // then
        #expect(mayRecognizeSimultaneously == expected)
    }

    private enum Companion: Sendable {
        case pan
        case tap
        case longPress
    }

    private enum Event: Equatable, Sendable {
        case began(CGPoint)
        case changed(CGPoint)
        case ended
        case cancelled
    }
}
