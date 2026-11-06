import Foundation

import ServerGitDomain
import ServerWorktreesDomain

actor FakeWorktreeObservationSource: WorktreeObservationSource {
    private let watches = AsyncStream.makeStream(of: [RepositoryLocation].self)
    private var streams: [UUID: AsyncStream<WorktreeObservationEvent>.Continuation] = [:]
    private(set) var watched: [[RepositoryLocation]] = []
    private var failures: [WorktreeObservationError]

    init(failures: [WorktreeObservationError] = []) { self.failures = failures }

    func events(
        watching locations: [RepositoryLocation]
    ) async throws(WorktreeObservationError) -> AsyncStream<WorktreeObservationEvent> {
        watched.append(locations)
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
}
