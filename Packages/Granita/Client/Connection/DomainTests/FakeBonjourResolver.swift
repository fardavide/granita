import Synchronization

import ClientConnectionDomain

/// Answers where a browsed Mac is, and counts how often it was asked.
///
/// **The count is the point of this one existing beside the Presentation module's own resolver.**
/// What the reconnection promises is that a Mac is looked up once and then kept, and that a read
/// which could not reach it throws the lookup away — neither of which is visible in the answer, only
/// in how many times the question was put.
final class FakeBonjourResolver: ServerAddressResolving {

    var lookups: Int { asked.withLock { $0 } }
    var cancelledLookups: Int { cancelled.withLock { $0 } }

    private let answering: Result<ServerAddress, ServerAddressResolutionFailure>
    private let asked = Mutex(0)
    private let cancelled = Mutex(0)
    private let isSuspended: Bool
    private let lookupStarted: AsyncStream<Void>
    private let lookupStartedContinuation: AsyncStream<Void>.Continuation
    private let suspendedLookup: AsyncStream<Void>
    private let suspendedLookupContinuation: AsyncStream<Void>.Continuation

    init(answering: Result<ServerAddress, ServerAddressResolutionFailure>, suspendingLookup: Bool = false) {
        self.answering = answering
        isSuspended = suspendingLookup
        let started = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        lookupStarted = started.stream
        lookupStartedContinuation = started.continuation
        let suspended = AsyncStream<Void>.makeStream()
        suspendedLookup = suspended.stream
        suspendedLookupContinuation = suspended.continuation
    }

    func waitUntilAsked() async {
        var events = lookupStarted.makeAsyncIterator()
        _ = await events.next()
    }

    func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        asked.withLock { $0 += 1 }
        lookupStartedContinuation.yield(())
        if isSuspended {
            var events = suspendedLookup.makeAsyncIterator()
            _ = await events.next()
            if Task.isCancelled {
                cancelled.withLock { $0 += 1 }
                throw .unreachable(diagnostic: "The losing Bonjour lookup was cancelled")
            }
        }
        switch answering {
        case .success(let address): return address
        case .failure(let failure): throw failure
        }
    }
}
