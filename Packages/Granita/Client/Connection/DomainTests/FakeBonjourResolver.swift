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

    private let response: Mutex<(address: Result<ServerAddress, ServerAddressResolutionFailure>, stages: [WorktreeReadStage])>
    private let asked = Mutex(0)
    private let cancelled = Mutex(0)
    private let isSuspended: Bool
    private let ignoresCancellation: Bool
    private let lookupStarted: AsyncStream<Void>
    private let lookupStartedContinuation: AsyncStream<Void>.Continuation
    private let suspendedLookup: AsyncStream<Void>
    private let suspendedLookupContinuation: AsyncStream<Void>.Continuation

    init(answering: Result<ServerAddress, ServerAddressResolutionFailure>, suspendingLookup: Bool = false, ignoringCancellation: Bool = false, reportingStages: [WorktreeReadStage] = []) {
        response = Mutex((answering, reportingStages))
        isSuspended = suspendingLookup
        ignoresCancellation = ignoringCancellation
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

    func resumeLookup() {
        suspendedLookupContinuation.yield(())
    }

    func answerWith(_ result: Result<ServerAddress, ServerAddressResolutionFailure>, reporting: [WorktreeReadStage]) {
        response.withLock { $0 = (result, reporting) }
    }

    func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        try await address(of: server, reporting: { _ in })
    }

    func address(of server: DiscoveredServer, reporting progress: @escaping @Sendable (WorktreeReadStage) async -> Void) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        let (address, stages) = response.withLock { $0 }
        for stage in stages {
            await progress(stage)
        }
        asked.withLock { $0 += 1 }
        lookupStartedContinuation.yield(())
        if isSuspended {
            var events = suspendedLookup.makeAsyncIterator()
            _ = await events.next()
            if Task.isCancelled && ignoresCancellation == false {
                cancelled.withLock { $0 += 1 }
                throw .unreachable(diagnostic: "The losing Bonjour lookup was cancelled")
            }
        }
        return try address.get()
    }
}
