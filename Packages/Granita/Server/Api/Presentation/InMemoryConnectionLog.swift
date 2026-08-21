import Foundation

import ServerApiDomain

/// The connection log, held for the life of this run of the server.
///
/// An actor because the middleware writes to it from whichever request is being served while the
/// Advanced panel reads it on the main actor.
public actor InMemoryConnectionLog: ConnectionLog {

    /// SPEC §9's fifty. A phone retrying every second fills that in under a minute, and what is
    /// wanted then is the last minute rather than the first.
    public static let capacity = 50

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
            recorded[0] = ConnectionAttempt(id: newest.id, at: now(), source: source, outcome: outcome)
        } else {
            recorded.insert(
                ConnectionAttempt(id: UUID(), at: now(), source: source, outcome: outcome),
                at: 0
            )
        }
        recorded = Array(recorded.prefix(Self.capacity))
        for reader in readers.values {
            reader.yield(recorded)
        }
    }

    public func attempts() -> AsyncStream<[ConnectionAttempt]> {
        let (stream, continuation) = AsyncStream<[ConnectionAttempt]>.makeStream()
        let reader = UUID()
        readers[reader] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stopReading(reader) }
        }
        continuation.yield(recorded)
        return stream
    }

    private func stopReading(_ reader: UUID) {
        readers[reader] = nil
    }
}
