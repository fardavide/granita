import Foundation

import ServerApiDomain

/// The connection log, held for the life of this run of the server.
///
/// An actor because the middleware writes to it from whichever request is being served while the
/// Advanced panel reads it on the main actor.
public actor InMemoryConnectionLog: ConnectionLog {

    private let now: @Sendable () -> Date
    private var recorded: [ConnectionAttempt] = []
    private var readers: [UUID: AsyncStream<[ConnectionAttempt]>.Continuation] = [:]

    public init(now: @escaping @Sendable () -> Date) {
        self.now = now
    }

    public func record(source: String, outcome: ConnectionOutcome) {
        // A phone polls, and a phone with the wrong token retries. Either fills the panel with one
        // sentence repeated fifty times and pushes off the row that explains the other device. So
        // the same thing happening again to the same source moves that row's time rather than
        // adding one: what is asked of the panel is when a phone last got in, not when it first did.
        if let newest = recorded.first, newest.source == source, newest.outcome == outcome {
            recorded[0] = ConnectionAttempt(
                id: newest.id,
                at: now(),
                source: source,
                outcome: outcome,
                // Counted rather than merely collapsed, because the row is the only place the size
                // of a retry storm is visible at all once the repeats stop being separate rows.
                occurrences: newest.occurrences + 1
            )
        } else {
            recorded.insert(
                ConnectionAttempt(id: UUID(), at: now(), source: source, outcome: outcome, occurrences: 1),
                at: 0
            )
        }
        recorded = Array(recorded.prefix(ConnectionAttempt.logCapacity))
        // A reader that has gone away is dropped here rather than announcing its own departure.
        // The obvious arrangement — `onTermination` hopping through a detached `Task` to remove
        // itself — worked, and its removal was reachable by no test: whether that task ran before
        // a process finished was a race, which showed up as a coverage row moving 0.1% on a runner
        // and not on a laptop for a branch that touched nothing near it. Pruning on the next write
        // is synchronous, is on a path every test already drives, and holds one terminated
        // continuation until the next attempt at worst.
        for (reader, continuation) in Array(readers) {
            if case .terminated = continuation.yield(recorded) {
                readers[reader] = nil
            }
        }
    }

    public func attempts() -> AsyncStream<[ConnectionAttempt]> {
        let (stream, continuation) = AsyncStream<[ConnectionAttempt]>.makeStream()
        readers[UUID()] = continuation
        continuation.yield(recorded)
        return stream
    }
}
