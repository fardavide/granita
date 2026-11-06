import Foundation

import CoreApiDomain
import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain

/// Why a worktree could not be handed over, in the vocabulary of this Mac rather than of HTTP.
///
/// **It carries no message, and that is the point of it being here.** The sentences a refusal
/// travels with are the API's, and this type is imported by the repository that reads this Mac with
/// no API in the path at all — so the wording lives at whichever boundary is doing the refusing, and
/// both of them spell the same three cases.
public enum WorktreeRegistryError: Error, Hashable, Sendable {

    /// The identifier names a project that exists but the reader has not enabled.
    ///
    /// Distinguished from finding nothing, because "you have not switched that on" and "there is no
    /// such thing" are different answers and only one of them is actionable.
    case projectNotVisible

    /// Resolved to a directory that is no longer on disk.
    case directoryGone

    /// No enabled project holds that worktree at all.
    case notFound

    case git(GitError)

    case cancelled

    /// How it travels, which is the one thing both boundaries agree on.
    public var code: ApiErrorCode {
        switch self {
        case .projectNotVisible: .projectNotVisible
        case .directoryGone, .notFound: .worktreeGone
        case .git, .cancelled: .gitFailure
        }
    }
}

/// Turns an opaque identifier into somewhere on this Mac, and refuses when it cannot.
///
/// This is where the API's most important rule is actually enforced. The client never sends a path;
/// it sends a hash, and the only paths that exist are the ones in the store, which are the ones the
/// user added by hand. A traversal attempt is not rejected here so much as unrepresentable: there
/// is nothing to traverse from.
///
/// **It is `Domain` because two things need it and they are on opposite sides of the layer graph**:
/// the routes that serve a phone, which are `Presentation` and carry Hummingbird, and the repository
/// that reads this Mac with no socket in the path. Its only filesystem access is behind
/// ``WorktreeDirectoryReading`` for exactly that reason.
public actor WorktreeRegistry {

    /// Somewhere resolvable, with everything needed to describe it.
    public struct Resolved: Sendable {
        public let location: RepositoryLocation
        public let project: StoredProject
        public let record: WorktreeRecord

        /// Whether this is the repository itself rather than a checkout of it.
        ///
        /// Taken from git's own ordering — `worktree list` puts the main worktree first — rather
        /// than by comparing the location against the project's folder, because the folder is
        /// whatever the reader added on the Mac and the ordering is a property of the command.
        public let isPrimary: Bool
    }

    private let store: any Store
    private let service: WorktreeService
    private let directory: any WorktreeDirectoryReading
    private let suggestedAliases: @Sendable ([(path: String, branch: String?)]) async -> [String: String]
    private let now: @Sendable () -> Date
    private var recordsByProject: [ProjectID: [WorktreeRecord]] = [:]
    private var changesByWorktree: [WorktreeID: WorktreeChangeSet] = [:]
    private var scanDates: [WorktreeID: Date] = [:]
    private var refreshFailures: [WorktreeID: WorktreeRegistryError] = [:]
    private var projectFailures: [ProjectID: WorktreeRegistryError] = [:]
    private var subscribers: [UUID: AsyncStream<WorktreeSnapshot>.Continuation] = [:]
    private var scans: [ProjectID: ProjectScan] = [:]
    private var requestedScans: [ProjectID: UInt64] = [:]
    private var completedScans: [ProjectID: UInt64] = [:]
    private var pendingScans: [ProjectID: ScanScope] = [:]
    private var scanLifetime = UUID()
    private var cacheVersion: UInt64 = 0
    private var publicationVersion: UInt64 = 0

    public init(
        store: any Store,
        service: WorktreeService,
        directory: any WorktreeDirectoryReading,
        suggestedAliases: @escaping @Sendable ([(path: String, branch: String?)]) async -> [String: String],
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.service = service
        self.directory = directory
        self.suggestedAliases = suggestedAliases
        self.now = now
    }

    public func projects() async -> [Project] {
        let lifetime = scanLifetime
        let state = await store.state()
        for stored in state.projects where stored.isVisible {
            do {
                try await prepare(stored, refreshing: false, invalidating: [], lifetime: lifetime, requirement: .availableProjects)
                projectFailures.removeValue(forKey: stored.id)
            } catch {
                projectFailures[stored.id] = error
            }
        }
        let current = await store.state()
        return current.projects.filter(\.isVisible).map { stored in
            let records = recordsByProject[stored.id] ?? []
            return Project(
                id: stored.id,
                name: stored.name,
                isVisible: stored.isVisible,
                worktreeCount: records.count,
                dirtyWorktreeCount: records.count {
                    changesByWorktree[WorktreeID(canonicalPath: $0.location.path)]?.files.isEmpty == false
                }
            )
        }
    }

    /// Drops what the store holds for worktrees that no longer exist, and caps the viewed marks.
    ///
    /// **`SPEC.md` §9's startup rule, and it has to be here rather than in the store**, because the
    /// store cannot know which worktrees are real — that answer costs a git process per project and
    /// belongs to whatever already runs them. An agent makes and destroys these checkouts, so
    /// nothing else would ever drop what they left behind.
    ///
    /// Failing is not worth reporting: this is housekeeping that runs at launch, and a Mac whose
    /// document could not be pruned still serves every route. It is tried again next launch.
    public func pruneStore(markLimit: Int = 20_000) async {
        let projects = await store.state().projects.filter(\.isVisible)
        var living: Set<WorktreeID> = []
        for project in projects {
            // **A project that cannot be read abandons the whole pass.** A repository on a volume
            // that has not mounted yet answers the same as one with no worktrees, and pruning on
            // that reading would delete a reader's marks and reviews for being unreachable rather
            // than for being gone. Housekeeping is never worth that, and there is another launch.
            guard let found = try? await service.worktrees(
                in: RepositoryLocation(path: project.path)
            ) else {
                return
            }
            living.formUnion(found.map { WorktreeID(canonicalPath: $0.location.path) })
        }
        try? await store.prune(keeping: living, markLimit: markLimit)
    }

    public func worktrees(inProject filter: ProjectID?) async throws(WorktreeRegistryError) -> [Worktree] {
        try await worktrees(inProject: filter, refreshing: false)
    }

    public func snapshot(
        inProject filter: ProjectID?,
        refreshing: Bool
    ) async throws(WorktreeRegistryError) -> WorktreeSnapshot {
        try await preparedSnapshot(inProject: filter, refreshing: refreshing, invalidating: [], requirement: .complete)
    }

    public func updates() async -> AsyncStream<WorktreeSnapshot> {
        let updates = AsyncStream.makeStream(of: WorktreeSnapshot.self, bufferingPolicy: .bufferingNewest(1))
        let subscription = UUID()
        subscribers[subscription] = updates.continuation
        updates.continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(subscription) }
        }
        let version = publicationVersion
        do {
            let snapshot = try await self.snapshot(inProject: nil, refreshing: false)
            // A broadcast during warming already seeded this registered subscriber. Its newer
            // buffered value must survive even if the initial read resumes afterward.
            if subscribers[subscription] != nil, publicationVersion == version {
                updates.continuation.yield(snapshot)
            }
        } catch {
            switch error {
            case .git:
                // Keep the subscription so a later successful reconciliation can seed it.
                break
            case .projectNotVisible, .directoryGone, .notFound, .cancelled:
                subscribers.removeValue(forKey: subscription)
                updates.continuation.finish()
            }
        }
        return updates.stream
    }

    public func observationLocations() async -> [RepositoryLocation] {
        let state = await store.state()
        var locations: [RepositoryLocation] = []
        for project in state.projects where project.isVisible {
            for location in [RepositoryLocation(path: project.path)]
                + (recordsByProject[project.id] ?? []).map(\.location) {
                if locations.contains(location) == false { locations.append(location) }
            }
        }
        return locations
    }

    public func storeDidChange() async {
        let lifetime = scanLifetime
        let state = await store.state()
        // A full-inventory event also removes absent rows on the client. Until every enabled
        // project has a successful inventory, omission means unknown rather than gone.
        guard state.projects.filter(\.isVisible).allSatisfy({ recordsByProject[$0.id] != nil }) else {
            return
        }
        do {
            let snapshot = try await renderedSnapshot(inProject: nil, lifetime: lifetime, requirement: .complete)
            publicationVersion += 1
            for continuation in subscribers.values { continuation.yield(snapshot) }
        } catch {
            for id in changesByWorktree.keys { refreshFailures[id] = error }
        }
    }

    public func stop() async {
        scanLifetime = UUID()
        let continuations = Array(subscribers.values)
        subscribers = [:]
        for continuation in continuations { continuation.finish() }
        let running = Array(scans.values)
        scans = [:]
        pendingScans = [:]
        for scan in running { scan.task.cancel() }
    }

    public func refresh(in worktrees: Set<WorktreeID>) async {
        do {
            _ = try await preparedSnapshot(inProject: nil, refreshing: false, invalidating: worktrees, requirement: .complete)
            for id in worktrees { refreshFailures.removeValue(forKey: id) }
            await storeDidChange()
        } catch {
            for id in worktrees { refreshFailures[id] = error }
            if recordsByProject.isEmpty == false { await storeDidChange() }
        }
    }

    public func reconcile() async {
        do {
            _ = try await worktrees(inProject: nil, refreshing: true)
            refreshFailures = [:]
            await storeDidChange()
        } catch {
            for id in changesByWorktree.keys { refreshFailures[id] = error }
            if recordsByProject.isEmpty == false { await storeDidChange() }
        }
    }

    public func didRemove(_ worktree: WorktreeID) async {
        // An enumeration already in flight can still contain this checkout. Keep the removal
        // with that attempt so its useful changes for other checkouts can still be committed.
        for project in Array(scans.keys) {
            scans[project]?.removedWorktrees.insert(worktree)
        }
        for project in Array(recordsByProject.keys) {
            recordsByProject[project]?.removeAll {
                WorktreeID(canonicalPath: $0.location.path) == worktree
            }
        }
        changesByWorktree.removeValue(forKey: worktree)
        scanDates.removeValue(forKey: worktree)
        refreshFailures.removeValue(forKey: worktree)
        cacheVersion += 1
        await storeDidChange()
    }

    public func worktrees(
        inProject filter: ProjectID?,
        refreshing: Bool
    ) async throws(WorktreeRegistryError) -> [Worktree] {
        try await preparedSnapshot(inProject: filter, refreshing: refreshing, invalidating: [], requirement: .availableProjects).worktrees
    }

    private func preparedSnapshot(
        inProject filter: ProjectID?,
        refreshing: Bool,
        invalidating: Set<WorktreeID>,
        requirement: InventoryRequirement
    ) async throws(WorktreeRegistryError) -> WorktreeSnapshot {
        let lifetime = scanLifetime
        let state = await store.state()
        guard scanLifetime == lifetime else { throw .cancelled }
        let projects = state.projects.filter { $0.isVisible && (filter == nil || $0.id == filter) }
        if let filter, projects.isEmpty, state.projects.contains(where: { $0.id == filter }) {
            throw .projectNotVisible
        }
        let failures = await withTaskGroup(of: Result<Void, WorktreeRegistryError>.self) { group in
            for project in projects {
                group.addTask {
                    do throws(WorktreeRegistryError) {
                        try await self.prepare(
                            project, refreshing: refreshing, invalidating: invalidating, lifetime: lifetime,
                            requirement: requirement
                        )
                        return .success(())
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var failures: [WorktreeRegistryError] = []
            for await result in group {
                if case .failure(let error) = result { failures.append(error) }
            }
            return failures
        }
        guard scanLifetime == lifetime else { throw .cancelled }
        if let failure = failures.first { throw failure }
        return try await renderedSnapshot(inProject: filter, lifetime: lifetime, requirement: requirement)
    }

    private func renderedSnapshot(
        inProject filter: ProjectID?,
        lifetime: UUID,
        requirement: InventoryRequirement
    ) async throws(WorktreeRegistryError) -> WorktreeSnapshot {
        while true {
            let version = cacheVersion
            let latest = await store.state()
            let visible = latest.projects.filter { $0.isVisible && (filter == nil || $0.id == filter) }
            // Project visibility can change while another project's scan or alias read suspends.
            // A full snapshot must include a successful inventory for the final visible set.
            for project in visible where recordsByProject[project.id] == nil {
                try await prepare(project, refreshing: false, invalidating: [], lifetime: lifetime, requirement: requirement)
            }
            guard cacheVersion == version else { continue }
            let records = visible.flatMap { project in
                (recordsByProject[project.id] ?? []).map { (project, $0) }
            }
            let preparedChanges = changesByWorktree
            let preparedDates = scanDates
            let suggestions = await suggestedAliases(records.map {
                ($0.1.location.path, $0.1.branch.map(Self.shortBranch))
            })
            let overlays = await store.state()
            guard scanLifetime == lifetime else { throw .cancelled }
            // Alias discovery can suspend while another scan publishes newer content. Render again
            // from that committed cache rather than letting an older snapshot overtake it.
            guard cacheVersion == version else { continue }
            guard overlays.projects.filter({ $0.isVisible && (filter == nil || $0.id == filter) }) == visible else {
                continue
            }
            var worktrees: [Worktree] = []
            for (project, record) in records {
                let id = WorktreeID(canonicalPath: record.location.path)
                if overlays.projects.contains(where: { $0.id == project.id && $0.isVisible }),
                   let changes = preparedChanges[id] {
                    worktrees.append(described(
                        record,
                        of: project,
                        changes: changes,
                        // Git lists each project's primary checkout first.
                        isPrimary: recordsByProject[project.id]?.first?.location == record.location,
                        suggestedAlias: suggestions[record.location.path],
                        stored: overlays.worktrees[id],
                        viewed: overlays.viewed[id]?.mapValues(\.contentHash) ?? [:]
                    ))
                }
            }
            return WorktreeSnapshot(
                worktrees: worktrees,
                scannedAt: worktrees.compactMap { preparedDates[$0.id] }.min() ?? now()
            )
        }
    }

    private func prepare(
        _ project: StoredProject,
        refreshing: Bool,
        invalidating: Set<WorktreeID>,
        lifetime: UUID,
        requirement: InventoryRequirement
    ) async throws(WorktreeRegistryError) {
        guard scanLifetime == lifetime else { throw .cancelled }
        let cached = recordsByProject[project.id]
        // Legacy lists tolerate missing enabled folders, but omission is not a successful inventory
        // and must never seed the complete snapshots that remove rows on connected clients.
        if case .availableProjects = requirement,
           cached == nil, directory.exists(at: RepositoryLocation(path: project.path)) == false {
            return
        }
        let requiresRefresh = refreshing || (cached ?? []).contains {
            invalidating.contains(WorktreeID(canonicalPath: $0.location.path))
        }
        if requiresRefresh == false, let cached,
           cached.allSatisfy({ changesByWorktree[WorktreeID(canonicalPath: $0.location.path)] != nil }) {
            return
        }
        let requested: UInt64
        if requiresRefresh {
            requested = (requestedScans[project.id] ?? 0) + 1
            requestedScans[project.id] = requested
            let scope: ScanScope = refreshing ? .all : .worktrees(invalidating)
            pendingScans[project.id] = pendingScans[project.id].map { $0.including(scope) } ?? scope
        } else {
            requested = completedScans[project.id] ?? 0
        }
        while true {
            if let running = scans[project.id] {
                let result = await running.task.value
                guard scanLifetime == lifetime else { throw .cancelled }
                if requiresRefresh, (completedScans[project.id] ?? 0) < requested { continue }
                switch result {
                case .success: return
                case .failure(let error): throw .git(error)
                }
            }
            let scope = pendingScans.removeValue(forKey: project.id) ?? .missing
            let generation = requestedScans[project.id] ?? 0
            let attempt = UUID()
            let task = Task { () -> Result<PreparedProject, GitError> in
                let result: Result<PreparedProject, GitError>
                do throws(GitError) {
                    let invalidated: Set<WorktreeID>
                    let refresh: Bool
                    switch scope {
                    case .missing: invalidated = []; refresh = false
                    case .all: invalidated = []; refresh = true
                    case .worktrees(let ids): invalidated = ids; refresh = false
                    }
                    result = .success(try await self.prepared(project, refreshing: refresh, invalidating: invalidated))
                } catch {
                    result = .failure(error)
                }
                await self.complete(project, attempt: attempt, generation: generation, result: result)
                return result
            }
            scans[project.id] = ProjectScan(attempt: attempt, task: task, removedWorktrees: [])
            let result = await task.value
            guard scanLifetime == lifetime else { throw .cancelled }
            if requiresRefresh, (completedScans[project.id] ?? 0) < requested { continue }
            switch result {
            case .success: return
            case .failure(let error): throw .git(error)
            }
        }
    }

    private func prepared(
        _ project: StoredProject,
        refreshing: Bool,
        invalidating: Set<WorktreeID>
    ) async throws(GitError) -> PreparedProject {
        let records = try await service.worktrees(in: RepositoryLocation(path: project.path))
        let previous = recordsByProject[project.id] ?? []
        var changes: [WorktreeID: WorktreeChangeSet] = [:]
        var dates: [WorktreeID: Date] = [:]
        for record in records {
            let id = WorktreeID(canonicalPath: record.location.path)
            if refreshing == false, invalidating.contains(id) == false,
               previous.first(where: { $0.location == record.location })?.head == record.head,
               let cached = changesByWorktree[id] {
                changes[id] = cached
                dates[id] = scanDates[id]
            } else {
                changes[id] = try await service.changeSet(in: record.location, viewed: [:])
                dates[id] = now()
            }
        }
        return PreparedProject(records: records, changes: changes, dates: dates)
    }

    private func complete(
        _ project: StoredProject,
        attempt: UUID,
        generation: UInt64,
        result: Result<PreparedProject, GitError>
    ) async {
        let state = await store.state()
        guard let scan = scans[project.id], scan.attempt == attempt else { return }
        scans.removeValue(forKey: project.id)
        completedScans[project.id] = generation
        guard state.projects.contains(where: { $0.id == project.id && $0.isVisible }) else { return }
        if case .success(let prepared) = result {
            cacheVersion += 1
            recordsByProject[project.id] = prepared.records.filter {
                scan.removedWorktrees.contains(WorktreeID(canonicalPath: $0.location.path)) == false
            }
            changesByWorktree.merge(prepared.changes) { _, current in current }
            scanDates.merge(prepared.dates) { _, current in current }
            let living = Set(recordsByProject.values.flatMap { $0 }.map {
                WorktreeID(canonicalPath: $0.location.path)
            })
            changesByWorktree = changesByWorktree.filter { living.contains($0.key) }
            scanDates = scanDates.filter { living.contains($0.key) }
        }
    }

    /// One worktree, described the way the list describes every worktree.
    ///
    /// **This exists so the route that writes an alias does not have to read the whole Mac to answer.**
    /// It used to call `worktrees(inProject: nil)` and pick its own row out of the result, which
    /// costs a change set — a `status`, a `diff` and a batched `hash-object` — for every worktree of
    /// every enabled project. On ten real repositories that is over two minutes, and it was the
    /// latency of renaming a worktree from a phone.
    ///
    /// It takes the `Resolved` the route already has rather than an identifier, so the enumeration
    /// that resolved it is not run a second time.
    public func worktree(_ resolved: Resolved) async throws(WorktreeRegistryError) -> Worktree {
        let state = await store.state()
        let suggestions = await suggestedAliases([
            (resolved.record.location.path, resolved.record.branch.map(Self.shortBranch))
        ])
        let id = WorktreeID(canonicalPath: resolved.location.path)
        let changes: WorktreeChangeSet
        do {
            if let cached = changesByWorktree[id] {
                changes = cached
            } else {
                changes = try await service.changeSet(in: resolved.location, viewed: [:])
                changesByWorktree[id] = changes
                scanDates[id] = now()
                cacheVersion += 1
            }
        } catch {
            throw .git(error)
        }
        return described(
            resolved.record,
            of: resolved.project,
            changes: changes,
            isPrimary: resolved.isPrimary,
            suggestedAlias: suggestions[resolved.record.location.path],
            stored: state.worktrees[id],
            viewed: state.viewed[id]?.mapValues(\.contentHash) ?? [:]
        )
    }

    /// Everything the phone is told about one checkout, from what has already been read about it.
    ///
    /// **Whether it is the primary checkout is a parameter rather than a question asked here**,
    /// because the two callers answer it in ways neither can borrow: the list reads git's ordering
    /// across a whole project, and a single resolution already knows, having enumerated that project
    /// to find this record at all. The stored row and the suggested name come in for the cheaper
    /// reason — the list reads the document once and batches the suggestions for every checkout it is
    /// describing, and doing either per worktree would put the cost back that this exists to remove.
    private func described(
        _ record: WorktreeRecord,
        of project: StoredProject,
        changes: WorktreeChangeSet,
        isPrimary: Bool,
        suggestedAlias suggested: String?,
        stored: StoredWorktree?,
        viewed: [FileID: String]
    ) -> Worktree {
        let branch = record.branch.map(Self.shortBranch)
        let directoryName = (record.location.path as NSString).lastPathComponent
        return Worktree(
            id: WorktreeID(canonicalPath: record.location.path),
            projectId: project.id,
            projectName: project.name,
            branch: branch,
            isPrimary: isPrimary,
            isDetached: record.isDetached,
            isLocked: record.isLocked,
            hasUnbornHead: record.head == nil,
            alias: stored?.alias,
            suggestedAlias: suggested,
            displayName: stored?.alias ?? suggested ?? branch ?? directoryName,
            directoryName: directoryName,
            isPinned: stored?.isPinned ?? false,
            stats: changes.stats,
            lastModified: directory.lastModified(at: record.location),
            revision: changes.revision
        ).withViewedFileCount(changes.files.count { viewed[$0.id] == $0.contentHash })
    }

    /// Where a worktree is, or why it cannot be served.
    public func resolve(_ id: WorktreeID) async throws(WorktreeRegistryError) -> Resolved {
        let state = await store.state()
        for project in state.projects where project.isVisible {
            let records = (try? await service.worktrees(in: RepositoryLocation(path: project.path))) ?? []
            for record in records where WorktreeID(canonicalPath: record.location.path) == id {
                guard directory.exists(at: record.location) else {
                    throw .directoryGone
                }
                return Resolved(
                    location: record.location,
                    project: project,
                    record: record,
                    isPrimary: records.first?.location == record.location
                )
            }
        }
        throw .notFound
    }

    private static func shortBranch(_ ref: String) -> String {
        ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
    }

    private func removeSubscriber(_ subscription: UUID) {
        subscribers.removeValue(forKey: subscription)
    }

    private struct PreparedProject: Sendable {
        let records: [WorktreeRecord]
        let changes: [WorktreeID: WorktreeChangeSet]
        let dates: [WorktreeID: Date]
    }

    private enum InventoryRequirement {
        case complete
        case availableProjects
    }

    private struct ProjectScan {
        let attempt: UUID
        let task: Task<Result<PreparedProject, GitError>, Never>
        var removedWorktrees: Set<WorktreeID>
    }

    private enum ScanScope {
        case missing
        case all
        case worktrees(Set<WorktreeID>)

        func including(_ other: Self) -> Self {
            switch (self, other) {
            case (.all, _), (_, .all): .all
            case (.missing, .missing): .missing
            case (.worktrees(let ids), .missing), (.missing, .worktrees(let ids)): .worktrees(ids)
            case (.worktrees(let first), .worktrees(let second)): .worktrees(first.union(second))
            }
        }
    }
}
