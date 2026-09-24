import Foundation

import CoreDiffDomain
import CoreReviewDomain
import ServerGitDomain
import ServerStoreDomain

/// Everything this Mac can be asked about its own worktrees, with no caller's vocabulary in it.
///
/// **This is the seam issue #97 is for.** It used to live inside the HTTP route handlers, which made
/// the routes the only way to read a Mac — so the merged app's window, running on the machine that
/// holds the worktrees, would have had to reimplement the interesting half: folding the store's
/// viewed marks into the git call, running four git processes at a time and returning them in the
/// order they were asked for, taking a rename's committed side from its *old* path, refusing a mark
/// against content nobody read. Two implementations of those would drift, and the drift would be
/// invisible until a reader saw two different answers for the same worktree.
///
/// So the routes and the window are both callers now, and neither owns the behaviour. What stays at
/// each boundary is the wording, because a wire message and a screen's sentence are different jobs.
public struct WorktreeReader: Sendable {

    /// `SPEC.md` §8's ceiling on one batched request, so a caller cannot ask for a hundred diffs and
    /// spawn a hundred git processes.
    public static let maximumBatchedFiles = 20

    /// At most this many git processes at once. The point of batching is to stop a forty-file
    /// worktree being forty-one round trips; it is not to run forty subprocesses.
    public static let concurrentGitProcesses = 4

    private let registry: WorktreeRegistry
    private let service: WorktreeService
    private let store: any Store

    public init(registry: WorktreeRegistry, service: WorktreeService, store: any Store) {
        self.registry = registry
        self.service = service
        self.store = store
    }

    // MARK: - Listing

    public func projects() async -> [Project] {
        await registry.projects()
    }

    public func worktrees(inProject filter: ProjectID?) async throws(WorktreeReadError) -> [Worktree] {
        do {
            return try await registry.worktrees(inProject: filter)
        } catch {
            throw WorktreeReadError(error)
        }
    }

    /// `SPEC.md` §9's startup housekeeping: drop what the store holds for worktrees that no longer
    /// exist, and cap the viewed marks.
    public func pruneStore(markLimit: Int = 20_000) async {
        await registry.pruneStore(markLimit: markLimit)
    }

    // MARK: - Writing to this Mac's own document

    /// Renames or pins, and answers with the worktree as it now stands.
    ///
    /// **It answers about the one worktree it wrote to, and that is the difference between a rename
    /// taking a moment and taking minutes.** Reading the whole list back would build a change set —
    /// `status`, `diff`, a batched `hash-object` — for every worktree of every enabled project.
    public func update(
        _ id: WorktreeID,
        with patch: WorktreePatch
    ) async throws(WorktreeReadError) -> Worktree {
        let resolved = try await resolve(id)
        do {
            switch patch.alias {
            case .unchanged: break
            case .cleared: try await store.setAlias(nil, for: id)
            case .set(let alias): try await store.setAlias(alias, for: id)
            }
            if let isPinned = patch.isPinned {
                try await store.setPinned(isPinned, for: id)
            }
        } catch {
            throw .notSaved(reason: "\(error)")
        }
        return await registry.worktree(resolved)
    }

    /// Takes a checkout off this Mac, with whatever uncommitted work is in it.
    ///
    /// **The only operation that destroys anything**, and the only one that writes to a repository
    /// rather than to this Mac's own document. It is `worktree remove --force --force`.
    ///
    /// **A lock does not refuse it**, which reversed the call this shipped with: nobody sets one by
    /// hand and Claude Code sets one on every worktree it creates, so reading a lock as a refusal
    /// refused essentially every row the control was offered on. The confirmation says it is locked
    /// instead. The branch is left alone.
    public func delete(_ id: WorktreeID) async throws(WorktreeReadError) {
        let resolved = try await resolve(id)

        // Refused here rather than by git, for the one case this Mac can see coming. Git refuses it
        // as well — exit 128, `is a main working tree` — so this is a better sentence rather than
        // the only guard, and the caller gets something it can branch on instead of a git message
        // it can only print.
        guard resolved.isPrimary == false else {
            throw .notDeletable
        }

        do {
            try await service.remove(
                resolved.location,
                ofProjectAt: RepositoryLocation(path: resolved.project.path)
            )
        } catch {
            throw .git(error)
        }
    }

    // MARK: - Reading a worktree

    public func changes(in id: WorktreeID) async throws(WorktreeReadError) -> WorktreeChanges {
        let resolved = try await resolve(id)
        let changes = try await changeSet(at: resolved.location, for: id)
        return WorktreeChanges(
            revision: changes.revision,
            stats: changes.stats,
            files: changes.files,
            isTruncated: changes.isTruncated
        )
    }

    public func diffs(
        of requested: [FileID],
        in id: WorktreeID,
        contextLines: Int
    ) async throws(WorktreeReadError) -> [FileDiff] {
        guard requested.count <= Self.maximumBatchedFiles else {
            throw .tooManyFiles(limit: Self.maximumBatchedFiles)
        }
        let resolved = try await resolve(id)
        let changes = try await changeSet(at: resolved.location, for: id)
        return try await diffs(
            for: requested,
            in: changes,
            at: resolved.location,
            contextLines: contextLines
        )
    }

    public func diff(
        of file: FileID,
        in id: WorktreeID,
        contextLines: Int
    ) async throws(WorktreeReadError) -> FileDiff {
        let resolved = try await resolve(id)
        let changes = try await changeSet(at: resolved.location, for: id)
        let produced = try await diffs(
            for: [file],
            in: changes,
            at: resolved.location,
            contextLines: contextLines
        )
        guard let only = produced.first else {
            throw .fileNotInChanges
        }
        return only
    }

    public func lines(
        of file: FileID,
        in id: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(WorktreeReadError) -> FileLines {
        let resolved = try await resolve(id)
        let changes = try await changeSet(at: resolved.location, for: id)
        guard let path = changes.paths[file] else {
            throw .fileNotInChanges
        }

        // A rename has two paths and the committed side only exists at the old one, so asking for
        // `HEAD:<new path>` fails outright rather than returning nothing.
        let readFrom = side == .old ? (changes.oldPaths[file] ?? path) : path
        do {
            let read = try await service.lines(
                of: readFrom,
                side: side,
                start: start,
                count: min(500, count),
                in: resolved.location
            )
            return FileLines(lines: read.lines, eof: read.isAtEnd)
        } catch {
            throw .git(error)
        }
    }

    /// One side of a changed picture, with the format the path claims.
    ///
    /// The format comes back because a caller putting this on a wire needs a media type for it, and
    /// deciding that twice is two places to get it wrong.
    public func image(
        of file: FileID,
        in id: WorktreeID,
        side: DiffSide
    ) async throws(WorktreeReadError) -> (bytes: Data, format: ImageFormat) {
        let resolved = try await resolve(id)
        let changes = try await changeSet(at: resolved.location, for: id)
        guard let path = changes.paths[file], let current = changes.files.first(where: { $0.id == file })
        else {
            throw .fileNotInChanges
        }

        // **Refused on what the path claims rather than on what git called binary**, which is the
        // same rule the phone applies: an untracked file is never reported binary, so a screenshot
        // an agent has just written would otherwise be the one picture this would not serve.
        guard let format = ImageFormat.forPath(current.path) else {
            throw .notAPicture
        }

        // A rename's two sides live at two paths and the committed one only exists at the old one,
        // so asking for `HEAD:<new path>` fails outright — the same trap the lines read documents,
        // reached here by a file that was moved and edited in one go.
        let readFrom = side == .old ? (changes.oldPaths[file] ?? path) : path
        do {
            let bytes = try await service.imageBytes(of: readFrom, side: side, in: resolved.location)
            return (bytes, format)
        } catch {
            // A `switch` rather than three `catch` patterns, because a pattern list the compiler
            // does not check for exhaustiveness would let a fourth reason escape unclassified.
            switch error {
            case .git(let failure): throw .git(failure)
            case .tooLarge: throw .pictureTooLarge
            case .unreadable(let reason): throw .fileUnreadable(reason: reason)
            }
        }
    }

    public func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in id: WorktreeID,
        at moment: Date
    ) async throws(WorktreeReadError) {
        let resolved = try await resolve(id)
        let changes = try await changeSet(at: resolved.location, for: id)

        guard let current = changes.files.first(where: { $0.id == file }) else {
            throw .fileNotInChanges
        }
        // Refused rather than applied: marking a version nobody read as read is the one way this
        // feature can actively mislead someone.
        guard current.contentHash == contentHash else {
            throw .staleContentHash
        }

        do {
            try await store.setViewed(
                viewed,
                file: file,
                in: id,
                contentHash: contentHash,
                at: moment
            )
        } catch {
            throw .notSaved(reason: "\(error)")
        }
    }

    // MARK: - The review

    public func review(in id: WorktreeID) async throws(WorktreeReadError) -> [ReviewComment] {
        // Resolved rather than trusted, like every other worktree operation: an identifier that
        // names nothing this Mac serves is answered the same way everywhere.
        _ = try await resolve(id)
        return await store.state().reviews[id] ?? []
    }

    public func putReview(
        _ comments: [ReviewComment],
        in id: WorktreeID
    ) async throws(WorktreeReadError) {
        _ = try await resolve(id)
        do {
            try await store.setReview(comments, in: id)
        } catch {
            throw .notSaved(reason: "\(error)")
        }
    }

    public func reviewSettings() async -> ReviewSettings {
        await store.state().reviewSettings
    }

    /// Changes only the settings named.
    ///
    /// The double optional is doing the work: an absent key leaves the setting alone and a null one
    /// clears it, so an edit queued on a device that never read this Mac's values cannot overwrite
    /// the one it did not touch.
    public func updateReviewSettings(
        openingLine: String??,
        identifier: ReviewIdentifier?
    ) async throws(WorktreeReadError) -> ReviewSettings {
        let current = await store.state().reviewSettings
        let updated = ReviewSettings(
            openingLine: openingLine ?? current.openingLine,
            identifier: identifier ?? current.identifier
        )
        do {
            try await store.setReviewSettings(updated)
        } catch {
            throw .notSaved(reason: "\(error)")
        }
        return updated
    }

    // MARK: - Shared work

    private func resolve(
        _ id: WorktreeID
    ) async throws(WorktreeReadError) -> WorktreeRegistry.Resolved {
        do {
            return try await registry.resolve(id)
        } catch {
            throw WorktreeReadError(error)
        }
    }

    private func changeSet(
        at location: RepositoryLocation,
        for worktree: WorktreeID
    ) async throws(WorktreeReadError) -> WorktreeChangeSet {
        do {
            // This worktree's marks and no other's. The service asks only which file was read at
            // which content, so the date the store keeps beside each mark stops here.
            let marks = await store.state().viewed[worktree] ?? [:]
            return try await service.changeSet(in: location, viewed: marks.mapValues(\.contentHash))
        } catch {
            throw .git(error)
        }
    }

    /// Computes several files' diffs at once, four git processes at a time.
    private func diffs(
        for requested: [FileID],
        in changes: WorktreeChangeSet,
        at location: RepositoryLocation,
        contextLines: Int
    ) async throws(WorktreeReadError) -> [FileDiff] {
        let wanted = changes.files.filter { requested.contains($0.id) }
        var produced: [FileID: FileDiff] = [:]

        do {
            try await withThrowingTaskGroup(of: (FileID, FileDiff)?.self) { group in
                var pending = wanted.makeIterator()
                var running = 0

                func addNext() -> Bool {
                    guard let file = pending.next(), let path = changes.paths[file.id] else { return false }
                    group.addTask {
                        let diff = try await service.fileDiff(
                            for: file,
                            at: path,
                            in: location,
                            contextLines: contextLines
                        )
                        return (file.id, diff)
                    }
                    return true
                }

                while running < Self.concurrentGitProcesses, addNext() { running += 1 }
                while let finished = try await group.next() {
                    if let finished { produced[finished.0] = finished.1 }
                    _ = addNext()
                }
            }
        } catch let failure as GitError {
            throw .git(failure)
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .gitUnknown(description: "\(error)")
        }

        // In the order the caller asked for, so a prefetch of the next five files arrives in the
        // order it will scroll through them.
        return requested.compactMap { produced[$0] }
    }
}

extension WorktreeReadError {

    /// The registry's three refusals, which are this type's first three cases.
    init(_ refusal: WorktreeRegistryError) {
        self = switch refusal {
        case .projectNotVisible: .projectNotVisible
        case .directoryGone: .directoryGone
        case .notFound: .notFound
        }
    }
}
