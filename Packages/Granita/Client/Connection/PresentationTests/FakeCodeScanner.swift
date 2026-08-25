import Synchronization

import ClientConnectionDomain
import CorePairingDomain

/// Reads whatever a test says was held up in front of the phone.
///
/// The run is fixed up front rather than scripted: design §5 tells its viewfinder states apart by
/// *what* came back — a stranger's code, one of ours that is broken, the one that pairs — and a fake
/// replaying a queue would invite tests that depend on how many frames went by without ever saying
/// so.
///
/// **It does not end on its own.** A camera that has read everything in front of it is still a
/// camera, and design §5's viewfinder ends only when a code is spent or the screen goes away — so
/// stopping is the only thing that ends this, which is how a real one behaves and the only way a
/// test can tell a scanner that was stopped from one that ran out.
final class FakeCodeScanner: CodeScanning {

    /// Whether the camera was stopped, which design §5 requires the instant a code is found: the
    /// frozen frame is the reader's only acknowledgement that the phone saw anything.
    var isStopped: Bool { state.withLock { $0.isStopped } }

    private let codes: [ScannedCode]
    private let state = Mutex(State())

    init(reading codes: [ScannedCode]) {
        self.codes = codes
    }

    func start() -> AsyncStream<ScannedCode> {
        AsyncStream { continuation in
            for code in codes {
                continuation.yield(code)
            }
            state.withLock { state in
                if state.isStopped {
                    continuation.finish()
                } else {
                    state.running = continuation
                }
            }
        }
    }

    func stop() {
        let running = state.withLock { state in
            state.isStopped = true
            defer { state.running = nil }
            return state.running
        }
        running?.finish()
    }

    private struct State {
        var isStopped = false
        var running: AsyncStream<ScannedCode>.Continuation?
    }
}
