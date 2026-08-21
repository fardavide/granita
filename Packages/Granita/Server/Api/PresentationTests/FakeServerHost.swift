import Foundation

import ServerApiDomain

/// A server that binds nothing and says whatever a test tells it to.
///
/// Not an actor, deliberately: `run()` has to have happened by the time it returns, so that a test
/// which observes a state can conclude *which run* produced it. An actor would make that an
/// ordering question and the assertions timing-dependent.
final class FakeServerHost: ServerHosting, @unchecked Sendable {

    private let lock = NSLock()
    private var runs: [AsyncStream<ServerRunState>.Continuation] = []
    private var startedRuns = 0
    private var endedRuns = 0

    /// How many times this has been asked to serve. Two means it was rebound.
    var runCount: Int {
        lock.withLock { startedRuns }
    }

    /// How many of those have finished — by cancellation, in every test here.
    var endedCount: Int {
        lock.withLock { endedRuns }
    }

    func run() -> AsyncStream<ServerRunState> {
        let (stream, continuation) = AsyncStream<ServerRunState>.makeStream()
        lock.withLock {
            startedRuns += 1
            runs.append(continuation)
        }
        continuation.onTermination = { [lock] _ in
            lock.withLock { self.endedRuns += 1 }
        }
        // Every real run begins by saying so, which is what lets a test tell one run from the next
        // without reaching into this object's counters.
        continuation.yield(.starting)
        return stream
    }

    /// Says something from the run that is currently up.
    func report(_ state: ServerRunState) {
        lock.withLock { runs.last }?.yield(state)
    }
}

/// A Mac that wakes when a test says so.
final class FakeWakeNotifications: WakeNotifications, @unchecked Sendable {

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation

    init() {
        (stream, continuation) = AsyncStream<Void>.makeStream()
    }

    func wakes() -> AsyncStream<Void> {
        stream
    }

    func wake() {
        continuation.yield(())
    }
}
