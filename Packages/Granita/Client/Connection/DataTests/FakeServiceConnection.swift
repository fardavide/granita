import Synchronization

@testable import ClientConnectionData

/// Answers however a test needs it to, standing in for the one thing a host test cannot have: a
/// connection that reaches a Mac and comes back with where it was.
///
/// It also remembers being cancelled. That is not tracking added for its own sake — "the connection
/// is never left running" is a promise the resolver makes on every path out of a lookup, and there
/// is nothing else about a fake connection that could show it was kept.
final class FakeServiceConnection: ServiceConnecting {

    /// Whether the resolver stopped it, which every return from a lookup must have done.
    var isCancelled: Bool { state.withLock { $0.isCancelled } }

    private let answer: FakeConnectionAnswer
    private let state = Mutex(State())

    init(answering answer: FakeConnectionAnswer) {
        self.answer = answer
    }

    func start() -> AsyncStream<EndpointResolution> {
        AsyncStream { continuation in
            switch answer {
            case .says(let resolution):
                continuation.yield(resolution)
                continuation.finish()
            case .saysNothingEver:
                // Held rather than finished, because a stream that ends on its own would answer the
                // question this case exists to leave open. Cancelling is the only thing that ends
                // it, which is exactly how a real connection behaves.
                state.withLock { state in
                    if state.isCancelled {
                        continuation.finish()
                    } else {
                        state.waiting = continuation
                    }
                }
            }
        }
    }

    func cancel() {
        let waiting = state.withLock { state in
            state.isCancelled = true
            defer { state.waiting = nil }
            return state.waiting
        }
        waiting?.finish()
    }

    private struct State {
        var isCancelled = false
        var waiting: AsyncStream<EndpointResolution>.Continuation?
    }
}

// MARK: -

/// What a fake connection does when it is started, configured up front rather than scripted: a
/// lookup is one question and a fake that replayed a queue would invite tests that depend on how
/// many times it was asked without ever saying so.
enum FakeConnectionAnswer: Sendable {

    case says(EndpointResolution)

    /// Never answers and never stops, which is the only way to make the resolver's patience run out
    /// on purpose.
    case saysNothingEver
}
