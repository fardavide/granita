import Synchronization

import ClientConnectionDomain

/// Stands in for the two things a test process cannot have: a camera grant recorded against a signed
/// app, and somebody in the room to answer the alert.
///
/// Configured with both halves up front, because both halves are screens. What the system already
/// says decides whether the alert is raised at all — design §5's first camera state is the one it
/// lands on — and what it would leave behind decides everything after it.
///
/// Remembering that it was asked is not tracking for its own sake: **iOS gives an app one prompt,
/// ever**, so "the alert was raised once, from the screen that can survive either answer" is a
/// promise design §5 makes and there is nothing else about a fake that could show it was kept.
///
/// How long the alert stays up is a knob for the same reason the answer is: design §5's first
/// camera state is only on screen while a person is deciding, so a fake that answered the instant it
/// was asked could never be asked what was behind the alert.
final class FakeCameraAuthorization: CameraAuthorizing {

    var current: CameraAccess { state.withLock { $0.current } }

    /// How many times the system alert was raised.
    var timesAsked: Int { state.withLock { $0.timesAsked } }

    private let answer: CameraAccess
    private let answeredAfter: Duration
    private let state: Mutex<State>

    init(_ current: CameraAccess, answering answer: CameraAccess, answeredAfter: Duration) {
        state = Mutex(State(current: current, timesAsked: 0))
        self.answer = answer
        self.answeredAfter = answeredAfter
    }

    func request() async -> CameraAccess {
        // Cancelling is how a test lets go of an alert it deliberately left standing: the answer it
        // configured still arrives, so the model ends where it would have ended anyway.
        try? await Task.sleep(for: answeredAfter)
        return state.withLock { state in
            state.current = answer
            state.timesAsked += 1
            return answer
        }
    }

    private struct State {
        var current: CameraAccess
        var timesAsked: Int
    }
}
