import Foundation

import CoreApiDomain

/// One live source for all consumers of a repository, retained only while somebody is listening.
public actor WorktreeUpdates {
    private let produce: @Sendable (@Sendable (WorktreeSnapshot) async -> Void) async throws(ApiFailure) -> Void
    private var subscribers: [UUID: AsyncStream<WorktreeUpdate>.Continuation] = [:]
    private var observation: Observation = .idle
    private var latest: Latest = .none
    private var retrySeconds = 1

    public init(
        receiving produce: @escaping @Sendable (@Sendable (WorktreeSnapshot) async -> Void) async throws(ApiFailure) -> Void
    ) {
        self.produce = produce
    }

    public func stream() -> AsyncStream<WorktreeUpdate> {
        let id = UUID()
        let pair = AsyncStream<WorktreeUpdate>.makeStream(bufferingPolicy: .bufferingNewest(8))
        subscribers[id] = pair.continuation
        if case .snapshot(let snapshot) = latest {
            pair.continuation.yield(.snapshot(snapshot))
        }
        pair.continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(id) }
        }
        if case .idle = observation {
            retrySeconds = 1
            let attempt = UUID()
            let task = Task { await observe(attempt) }
            observation = .running(attempt, task)
        }
        return pair.stream
    }

    private func observe(_ attempt: UUID) async {
        while owns(attempt), !Task.isCancelled {
            do {
                try await produce { snapshot in
                    await self.receive(snapshot, attempt: attempt)
                }
            } catch {
                guard owns(attempt), !Task.isCancelled else { return }
                let failure = error
                let update: WorktreeUpdate = if case .routeNotServed = failure {
                    .unsupported
                } else {
                    .failed(failure)
                }
                for continuation in subscribers.values { continuation.yield(update) }
                switch failure {
                case .unreachable, .rateLimited, .gitFailure:
                    break
                case .unauthorized, .pairingExpired, .projectNotVisible, .worktreeGone,
                     .worktreeNotDeletable, .fileGone, .staleContentHash, .tooLarge,
                     .badRequest, .unsupportedApiVersion, .routeNotServed,
                     .requestNotBuildable, .cancelled, .notUnderstood:
                    finish(attempt)
                    return
                }
            }
            do {
                try await Task.sleep(for: .seconds(retrySeconds))
            } catch {
                finish(attempt)
                return
            }
            retrySeconds = min(retrySeconds * 2, 30)
        }
        finish(attempt)
    }

    private func receive(_ snapshot: WorktreeSnapshot, attempt: UUID) {
        guard owns(attempt), !Task.isCancelled else { return }
        retrySeconds = 1
        latest = .snapshot(snapshot)
        for continuation in subscribers.values { continuation.yield(.snapshot(snapshot)) }
    }

    private func finish(_ attempt: UUID) {
        guard owns(attempt) else { return }
        observation = .idle
        latest = .none
        let finishing = subscribers.values
        subscribers = [:]
        for continuation in finishing { continuation.finish() }
    }

    private func remove(_ id: UUID) {
        subscribers.removeValue(forKey: id)
        if subscribers.isEmpty, case .running(_, let task) = observation {
            observation = .idle
            latest = .none
            task.cancel()
        }
    }

    private func owns(_ attempt: UUID) -> Bool {
        guard case .running(let current, _) = observation else { return false }
        return current == attempt
    }

    private enum Observation {
        case idle
        case running(UUID, Task<Void, Never>)
    }

    private enum Latest {
        case none
        case snapshot(WorktreeSnapshot)
    }
}
