import Foundation

import CoreDiffDomain
import ServerGitDomain
import ServerStoreDomain
import ServerWorktreesDomain

/// Turns an opaque identifier into somewhere on this Mac, and refuses when it cannot.
///
/// This is where the API's most important rule is actually enforced. The client never sends a path;
/// it sends a hash, and the only paths that exist are the ones in the store, which are the ones the
/// user added by hand. A traversal attempt is not rejected here so much as unrepresentable: there
/// is nothing to traverse from.
public struct WorktreeRegistry: Sendable {

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
    private let suggestedAliases: @Sendable ([(path: String, branch: String?)]) async -> [String: String]

    public init(
        store: any Store,
        service: WorktreeService,
        suggestedAliases: @escaping @Sendable ([(path: String, branch: String?)]) async -> [String: String]
    ) {
        self.store = store
        self.service = service
        self.suggestedAliases = suggestedAliases
    }

    public func projects() async -> [Project] {
        let state = await store.state()
        var projects: [Project] = []
        for stored in state.projects where stored.isVisible {
            let records = (try? await service.worktrees(in: RepositoryLocation(path: stored.path))) ?? []
            var dirty = 0
            for record in records {
                let changes = try? await service.changeSet(in: record.location, viewed: [:])
                if let changes, changes.files.isEmpty == false { dirty += 1 }
            }
            projects.append(Project(
                id: stored.id,
                name: stored.name,
                isVisible: stored.isVisible,
                worktreeCount: records.count,
                dirtyWorktreeCount: dirty
            ))
        }
        return projects
    }

    public func worktrees(inProject filter: ProjectID?) async throws(ApiError) -> [Worktree] {
        let state = await store.state()
        let projects = state.projects.filter { $0.isVisible && (filter == nil || $0.id == filter) }
        if let filter, projects.isEmpty, state.projects.contains(where: { $0.id == filter }) {
            throw ApiError(.projectNotVisible, message: "that project is not enabled")
        }

        var records: [(StoredProject, WorktreeRecord)] = []
        for project in projects {
            let found = (try? await service.worktrees(in: RepositoryLocation(path: project.path))) ?? []
            records.append(contentsOf: found.map { (project, $0) })
        }

        let suggestions = await suggestedAliases(records.map {
            ($0.1.location.path, $0.1.branch.map(Self.shortBranch))
        })

        var worktrees: [Worktree] = []
        for (index, entry) in records.enumerated() {
            let (project, record) = entry
            worktrees.append(await described(
                record,
                of: project,
                // The primary checkout is the one git lists first, which is the repository root
                // itself; everything after it is a linked worktree.
                isPrimary: index == 0 || record.location.path == project.path,
                suggestedAlias: suggestions[record.location.path],
                stored: state.worktrees[WorktreeID(canonicalPath: record.location.path)]
            ))
        }
        return worktrees
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
    public func worktree(_ resolved: Resolved) async -> Worktree {
        let state = await store.state()
        let suggestions = await suggestedAliases([
            (resolved.record.location.path, resolved.record.branch.map(Self.shortBranch))
        ])
        return await described(
            resolved.record,
            of: resolved.project,
            isPrimary: resolved.isPrimary,
            suggestedAlias: suggestions[resolved.record.location.path],
            stored: state.worktrees[WorktreeID(canonicalPath: resolved.record.location.path)]
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
        isPrimary: Bool,
        suggestedAlias suggested: String?,
        stored: StoredWorktree?
    ) async -> Worktree {
        let branch = record.branch.map(Self.shortBranch)
        let directoryName = (record.location.path as NSString).lastPathComponent
        let changes = try? await service.changeSet(in: record.location, viewed: [:])

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
            stats: changes?.stats ?? .zero,
            lastModified: modificationDate(of: record.location),
            revision: changes?.revision ?? ""
        )
    }

    /// Where a worktree is, or why it cannot be served.
    public func resolve(_ id: WorktreeID) async throws(ApiError) -> Resolved {
        let state = await store.state()
        for project in state.projects where project.isVisible {
            let records = (try? await service.worktrees(in: RepositoryLocation(path: project.path))) ?? []
            for record in records where WorktreeID(canonicalPath: record.location.path) == id {
                guard FileManager.default.fileExists(atPath: record.location.path) else {
                    throw ApiError(.worktreeGone, message: "that worktree's directory is no longer there")
                }
                return Resolved(
                    location: record.location,
                    project: project,
                    record: record,
                    isPrimary: records.first?.location == record.location
                )
            }
        }
        throw ApiError(.worktreeGone, message: "no enabled project has that worktree")
    }

    private func modificationDate(of location: RepositoryLocation) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: location.path)
        return attributes?[.modificationDate] as? Date ?? Date(timeIntervalSince1970: 0)
    }

    private static func shortBranch(_ ref: String) -> String {
        ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
    }
}
