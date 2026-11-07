import Foundation

import ServerGitDomain
import ServerWorktreesDomain

actor FakeWorktreeObservationSource: WorktreeObservationSource {
    private let watches = AsyncStream.makeStream(of: [RepositoryLocation].self)
    private var streams: [UUID: AsyncStream<WorktreeObservationEvent>.Continuation] = [:]
    private let pausedWatches = AsyncStream.makeStream(of: Void.self)
    private var opening: Opening = .ready
    private(set) var watched: [[RepositoryLocation]] = []
    private var failures: [WorktreeObservationError]

    init(failures: [WorktreeObservationError] = []) { self.failures = failures }

    var activeWatchCount: Int { streams.count }

    func pauseNextWatch() { opening = .requested }

    func waitUntilWatchPaused() async {
        var paused = pausedWatches.stream.makeAsyncIterator()
        _ = await paused.next()
    }

    func resumeWatch() {
        guard case .paused(let continuation) = opening else { return }
        opening = .ready
        continuation.resume()
    }

    func events(
        watching locations: [RepositoryLocation]
    ) async throws(WorktreeObservationError) -> AsyncStream<WorktreeObservationEvent> {
        watched.append(locations)
        if case .requested = opening {
            // A native startup can complete after cancellation; the owner must reject its result.
            await withCheckedContinuation { continuation in
                opening = .paused(continuation)
                pausedWatches.continuation.yield(())
            }
        }
        if failures.isEmpty == false {
            watches.continuation.yield(locations)
            throw failures.removeFirst()
        }
        let pair = AsyncStream.makeStream(of: WorktreeObservationEvent.self)
        let id = UUID()
        streams[id] = pair.continuation
        pair.continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(id) }
        }
        watches.continuation.yield(locations)
        return pair.stream
    }

    func nextWatch() async -> [RepositoryLocation]? {
        var iterator = watches.stream.makeAsyncIterator()
        return await iterator.next()
    }

    func send(_ event: WorktreeObservationEvent) {
        for continuation in streams.values { continuation.yield(event) }
    }

    func stop() {
        let previous = streams.values
        streams = [:]
        for continuation in previous { continuation.finish() }
    }

    private func remove(_ id: UUID) {
        streams.removeValue(forKey: id)
    }

    private enum Opening {
        case ready
        case requested
        case paused(CheckedContinuation<Void, Never>)
    }
}
