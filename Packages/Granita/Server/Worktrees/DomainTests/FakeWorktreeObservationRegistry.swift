import Foundation

import CoreApiDomain
import CoreDiffDomain
import ServerGitDomain
import ServerWorktreesDomain

actor FakeWorktreeObservationRegistry: WorktreeObservationRegistry {
    private var locations: [RepositoryLocation]
    private let reconciliations = AsyncStream.makeStream(of: Void.self)
    private let refreshes = AsyncStream.makeStream(of: Set<WorktreeID>.self)
    private let storeChanges = AsyncStream.makeStream(of: Void.self)
    private let snapshots = AsyncStream.makeStream(of: WorktreeSnapshot.self, bufferingPolicy: .bufferingNewest(1))
    private let subscriptions = AsyncStream.makeStream(of: Void.self)
    private let stops = AsyncStream.makeStream(of: Void.self)
    private var stopping: Stopping = .ready
    private(set) var reconciliationCount = 0
    private var discovered: Discovered = .unchanged

    init(locations: [RepositoryLocation]) {
        self.locations = locations
    }

    func observationLocations() -> [RepositoryLocation] { locations }
    func replaceLocations(_ locations: [RepositoryLocation]) { self.locations = locations }
    func discoverOnNextReconciliation(_ locations: [RepositoryLocation]) { discovered = .locations(locations) }
    func finishSnapshots() { snapshots.continuation.finish() }
    func updates() -> AsyncStream<WorktreeSnapshot> {
        snapshots.continuation.yield(WorktreeSnapshot(worktrees: [], scannedAt: Date(timeIntervalSince1970: 0)))
        subscriptions.continuation.yield(())
        return snapshots.stream
    }
    func publishLocations(_ locations: [RepositoryLocation]) {
        self.locations = locations
        snapshots.continuation.yield(WorktreeSnapshot(worktrees: [], scannedAt: Date(timeIntervalSince1970: 0)))
    }
    func reconcile() {
        reconciliationCount += 1
        switch discovered {
        case .unchanged: break
        case .locations(let found):
            locations = found
            discovered = .unchanged
        }
        reconciliations.continuation.yield(())
    }
    func refresh(in worktrees: Set<WorktreeID>) { refreshes.continuation.yield(worktrees) }
    func storeDidChange() { storeChanges.continuation.yield(()) }
    func stop() async {
        stops.continuation.yield(())
        await withCheckedContinuation { continuation in
            switch stopping {
            case .ready: continuation.resume()
            case .paused(var waiters):
                waiters.append(continuation)
                stopping = .paused(waiters)
            }
        }
        snapshots.continuation.finish()
    }

    func pauseStopping() { stopping = .paused([]) }

    func waitUntilStopping() async {
        var iterator = stops.stream.makeAsyncIterator()
        _ = await iterator.next()
    }

    func resumeStopping() {
        guard case .paused(let waiters) = stopping else { return }
        stopping = .ready
        for waiter in waiters { waiter.resume() }
    }

    func nextSubscription() async {
        var iterator = subscriptions.stream.makeAsyncIterator()
        _ = await iterator.next()
    }

    func nextReconciliation() async {
        var iterator = reconciliations.stream.makeAsyncIterator()
        _ = await iterator.next()
    }

    func nextRefresh() async -> Set<WorktreeID>? {
        var iterator = refreshes.stream.makeAsyncIterator()
        return await iterator.next()
    }

    func nextStoreChange() async -> Bool {
        var iterator = storeChanges.stream.makeAsyncIterator()
        return await iterator.next() != nil
    }

    private enum Stopping {
        case ready
        case paused([CheckedContinuation<Void, Never>])
    }

    private enum Discovered {
        case unchanged
        case locations([RepositoryLocation])
    }
}
