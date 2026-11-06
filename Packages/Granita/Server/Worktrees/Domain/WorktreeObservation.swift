import Foundation

import CoreApiDomain
import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain

public protocol WorktreeObservationRegistry: Sendable {
    func updates() async -> AsyncStream<WorktreeSnapshot>
    func observationLocations() async -> [RepositoryLocation]
    func refresh(in worktrees: Set<WorktreeID>) async
    func reconcile() async
    func storeDidChange() async
    func stop() async
}

extension WorktreeRegistry: WorktreeObservationRegistry {}

public actor WorktreeObservation {
    private let registry: any WorktreeObservationRegistry
    private let git: any GitClient
    private let source: any WorktreeObservationSource
    private let store: any Store
    private let onFailure: @Sendable (WorktreeObservationError) async -> Void
    private let timing: any WorktreeObservationTiming
    private var running: Run = .stopped
    private var schedule = WorktreeObservationSchedule()
    private var scheduled: Scheduled = .idle
    private var timers: [UUID: Task<Void, Never>] = [:]
    private var eventTasks: [UUID: Task<Void, Never>] = [:]

    public init(
        registry: any WorktreeObservationRegistry,
        git: any GitClient,
        source: any WorktreeObservationSource,
        store: any Store,
        onFailure: @escaping @Sendable (WorktreeObservationError) async -> Void,
        timing: any WorktreeObservationTiming = ContinuousWorktreeObservationTiming()
    ) {
        self.registry = registry
        self.git = git
        self.source = source
        self.store = store
        self.onFailure = onFailure
        self.timing = timing
    }

    public func run() async {
        guard case .stopped = running else { return }
        let id = UUID()
        let requests = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        let worker = Task {
            var retryDelay = Duration.seconds(1)
            for await _ in requests.stream {
                guard owns(id), Task.isCancelled == false else { return }
                do throws(WorktreeObservationError) {
                    try await observe(id)
                    guard owns(id), Task.isCancelled == false else { return }
                    schedule.didFinishReconciliation()
                    await scheduleTimer(run: id)
                    retryDelay = .seconds(1)
                }
                catch {
                    guard owns(id), Task.isCancelled == false else { return }
                    schedule.didFinishReconciliation()
                    await scheduleTimer(run: id)
                    await onFailure(error)
                    do { try await timing.sleep(for: retryDelay) }
                    catch { return }
                    retryDelay = min(retryDelay + retryDelay, .seconds(30))
                    guard owns(id), Task.isCancelled == false else { return }
                    switch error {
                    case .couldNotCreateStream, .couldNotStartStream:
                        requests.continuation.yield(())
                    case .git, .invalidGitDirectory:
                        await receive(.reconcile, run: id)
                    }
                }
            }
        }
        let stored = Task { await observeStore(id) }
        let inventory = Task { await observeInventory(id) }
        let workers = [worker, stored, inventory]
        running = .running(id, workers, requests.continuation)
        requests.continuation.yield(())
        await withTaskCancellationHandler {
            for worker in workers { await worker.value }
        } onCancel: {
            Task { await self.stop(id) }
        }
        await stop(id)
    }

    public func stop() async {
        let id: UUID
        let workers: [Task<Void, Never>]
        let requests: AsyncStream<Void>.Continuation
        switch running {
        case .stopped: return
        case .stopping(_, let teardown):
            await teardown.value
            return
        case .running(let current, let active, let continuation):
            id = current
            workers = active
            requests = continuation
        }
        requests.finish()
        for worker in workers { worker.cancel() }
        let pendingEvents = Array(eventTasks.values)
        eventTasks = [:]
        for task in pendingEvents { task.cancel() }
        let pendingTimers = Array(timers.values)
        timers = [:]
        scheduled = .idle
        schedule = WorktreeObservationSchedule()
        for timer in pendingTimers { timer.cancel() }
        let teardown = Task {
            await source.stop()
            await registry.stop()
            for timer in pendingTimers { await timer.value }
            for task in pendingEvents { await task.value }
            for worker in workers { await worker.value }
            finishStopping(id)
        }
        running = .stopping(id, teardown)
        await teardown.value
    }

    public func reconcile() async {
        guard case .running(let id, _, _) = running else { return }
        await receive(.reconcile, run: id)
    }

    private func observeStore(_ id: UUID) async {
        var previous = await store.state()
        for await state in await store.updates() {
            guard owns(id), Task.isCancelled == false else { return }
            if state.projects != previous.projects {
                await receive(.reconcile, run: id)
            }
            if state.worktrees != previous.worktrees || state.viewed != previous.viewed {
                await registry.storeDidChange()
            }
            previous = state
        }
    }

    private func observeInventory(_ id: UUID) async {
        var previous = Set(await registry.observationLocations())
        for await _ in await registry.updates() {
            let locations = Set(await registry.observationLocations())
            guard owns(id), Task.isCancelled == false else { return }
            if locations != previous { await receive(.reconcile, run: id) }
            previous = locations
        }
    }

    private func observe(_ id: UUID) async throws(WorktreeObservationError) {
        let previousEvents = Array(eventTasks.values)
        for task in previousEvents { task.cancel() }
        await source.stop()
        for task in previousEvents { await task.value }
        guard owns(id), Task.isCancelled == false else { return }
        var targets: Set<WorktreeObservationTarget> = []
        var failures: [WorktreeObservationError] = []
        var failedLocations: Set<RepositoryLocation> = []
        let locations = await registry.observationLocations()
        for location in locations {
            do throws(WorktreeObservationError) {
                targets.insert(try await target(at: location))
            } catch {
                guard owns(id), Task.isCancelled == false else { return }
                failures.append(error)
                failedLocations.insert(location)
            }
        }
        guard owns(id), Task.isCancelled == false else { return }
        let watched = Set(targets.flatMap { [$0.location, $0.gitDirectory, $0.commonGitDirectory] })
            .sorted { $0.path < $1.path }
        guard watched.isEmpty == false else {
            if let failure = failures.first { throw failure }
            await reconcileInventory(observedLocations: locations, run: id)
            return
        }
        for failure in failures { await onFailure(failure) }
        let events = try await source.events(watching: watched)
        guard owns(id), Task.isCancelled == false else {
            await source.stop()
            return
        }
        let topology = WorktreeObservationTopology(targets: Array(targets))
        let token = UUID()
        let consumer = Task {
            for await event in events {
                guard owns(id), Task.isCancelled == false else { break }
                await receive(topology.reaction(to: event), run: id)
            }
            eventTasks.removeValue(forKey: token)
        }
        eventTasks[token] = consumer
        schedule.didStartReconciliation(at: await timing.now())
        await reconcileInventory(observedLocations: locations, run: id)
        guard owns(id), Task.isCancelled == false else { return }
        retryDiscovery(in: failedLocations, run: id)
    }

    private func reconcileInventory(observedLocations: [RepositoryLocation], run id: UUID) async {
        await registry.reconcile()
        let current = Set(await registry.observationLocations())
        guard owns(id), Task.isCancelled == false else { return }
        if current != Set(observedLocations) { await receive(.reconcile, run: id) }
    }

    private func retryDiscovery(in locations: Set<RepositoryLocation>, run id: UUID) {
        guard locations.isEmpty == false else { return }
        let token = UUID()
        let retrying = Task {
            defer { eventTasks.removeValue(forKey: token) }
            var delay = Duration.seconds(1)
            while owns(id), Task.isCancelled == false {
                do { try await timing.sleep(for: delay) }
                catch { return }
                for location in locations {
                    guard owns(id), Task.isCancelled == false else { return }
                    do throws(WorktreeObservationError) {
                        _ = try await target(at: location)
                        guard owns(id), Task.isCancelled == false else { return }
                        await receive(.reconcile, run: id)
                        return
                    } catch {
                        guard owns(id), Task.isCancelled == false else { return }
                        await onFailure(error)
                    }
                }
                delay = min(delay + delay, .seconds(30))
            }
        }
        eventTasks[token] = retrying
    }

    private func receive(_ reaction: WorktreeObservationReaction, run id: UUID) async {
        let elapsed = await timing.now()
        guard owns(id), Task.isCancelled == false else { return }
        schedule.invalidate(reaction, at: elapsed)
        await scheduleTimer(run: id)
    }

    private func scheduleTimer(run id: UUID) async {
        let elapsed = await timing.now()
        guard owns(id) else { return }
        guard case .at(let deadline) = schedule.nextDeadline else { return }
        if case .waiting(_, let previous) = scheduled, previous <= deadline { return }
        if case .waiting(let previous, _) = scheduled { timers[previous]?.cancel() }
        let token = UUID()
        let delay = max(.zero, deadline - elapsed)
        let timer = Task {
            do { try await timing.sleep(for: delay) }
            catch {
                finishTimer(token)
                return
            }
            await fire(token, run: id)
            finishTimer(token)
        }
        timers[token] = timer
        scheduled = .waiting(token, deadline)
    }

    private func fire(_ token: UUID, run id: UUID) async {
        guard owns(id), case .waiting(let current, _) = scheduled, current == token else { return }
        scheduled = .idle
        let elapsed = await timing.now()
        guard owns(id) else { return }
        switch schedule.takeDue(at: elapsed) {
        case .refresh(let worktrees):
            await registry.refresh(in: worktrees)
            guard owns(id), Task.isCancelled == false else { return }
            schedule.didFinishRefresh(in: worktrees)
        case .reconcile:
            if case .running(_, _, let requests) = running {
                requests.yield(())
            }
        case .ignore: break
        }
        await scheduleTimer(run: id)
    }

    private func finishTimer(_ token: UUID) {
        timers.removeValue(forKey: token)
        if case .waiting(let current, _) = scheduled, current == token { scheduled = .idle }
    }

    private func directory(
        _ command: GitCommand,
        in location: RepositoryLocation
    ) async throws(WorktreeObservationError) -> RepositoryLocation {
        let output: GitOutput
        do { output = try await git.run(command, in: location) }
        catch { throw .git(error) }
        var path = String(decoding: output.standardOutput, as: UTF8.self)
        if path.hasSuffix("\n") { path.removeLast() }
        guard output.isTruncated == false, path.hasPrefix("/") else {
            throw .invalidGitDirectory(location)
        }
        return RepositoryLocation(path: path)
    }

    private func target(at location: RepositoryLocation) async throws(WorktreeObservationError) -> WorktreeObservationTarget {
        let checkout = try await directory(.repositoryRoot, in: location)
        let gitDirectory = try await directory(.gitDirectory, in: checkout)
        let common = try await directory(.commonGitDirectory, in: checkout)
        return WorktreeObservationTarget(location: checkout, gitDirectory: gitDirectory, commonGitDirectory: common)
    }

    private func stop(_ id: UUID) async {
        switch running {
        case .stopped: return
        case .running(let current, _, _), .stopping(let current, _):
            guard current == id else { return }
            await stop()
        }
    }

    private func finishStopping(_ id: UUID) {
        guard case .stopping(let current, _) = running, current == id else { return }
        running = .stopped
    }

    private func owns(_ id: UUID) -> Bool {
        switch running {
        case .stopped, .stopping: false
        case .running(let current, _, _): current == id
        }
    }

    private enum Run {
        case stopped
        case stopping(UUID, Task<Void, Never>)
        case running(UUID, [Task<Void, Never>], AsyncStream<Void>.Continuation)
    }

    private enum Scheduled {
        case idle
        case waiting(UUID, Duration)
    }
}
