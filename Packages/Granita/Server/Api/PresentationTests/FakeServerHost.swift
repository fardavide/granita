import Foundation
import Synchronization

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

    func finish() {
        lock.withLock { runs.last }?.finish()
    }
}

/// A Mac that wakes when a test says so.
final class FakeWakeNotifications: WakeNotifications {

    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private let delivery: Delivery
    private let subscriptions = Mutex(0)
    private let finite = FiniteDelivery()

    init(delivery: Delivery = .manual) {
        self.delivery = delivery
        (stream, continuation) = AsyncStream<Void>.makeStream()
    }

    func wakes() -> AsyncStream<Void> {
        switch delivery {
        case .manual: return stream
        case .finite:
            let subscription = subscriptions.withLock { count in
                count += 1
                return count
            }
            return AsyncStream(unfolding: { [finite] in await finite.next(subscription: subscription) })
        }
    }

    func wake() {
        continuation.yield(())
    }

    func allowFiniteWake() async { await finite.allow() }

    enum Delivery: Sendable {
        case manual
        case finite
    }

    private actor FiniteDelivery {
        private var allowed = false
        private var delivered = false
        private var drained = false
        private var waitingToAllow: [CheckedContinuation<Void, Never>] = []
        private var waitingToDrain: [CheckedContinuation<Void, Never>] = []

        func allow() {
            allowed = true
            for waiter in waitingToAllow { waiter.resume() }
            waitingToAllow = []
        }

        func next(subscription: Int) async -> Void? {
            if subscription == 1 {
                if allowed == false { await withCheckedContinuation { waitingToAllow.append($0) } }
                if delivered == false {
                    delivered = true
                    return ()
                }
                drained = true
                for waiter in waitingToDrain { waiter.resume() }
                waitingToDrain = []
                return nil
            }
            if drained == false { await withCheckedContinuation { waitingToDrain.append($0) } }
            return nil
        }
    }
}
