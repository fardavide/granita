import Foundation
import Observation

import ClientConnectionDomain
import CoreApiDomain
import CoreDiffDomain
import CoreReviewDomain

/// Serves a bounded file with real line-window semantics to the production reader model.
@Observable
@MainActor
final class FakeGranitaRepository: GranitaRepository {

    private let diff: FileDiff
    private let content: [String]
    private let liveWorktrees: [WorktreeID]
    private var revisions: [WorktreeID: Int]
    private var reads: [WorktreeID: Int] = [:]
    private var observers: [UUID: AsyncStream<WorktreeUpdate>.Continuation] = [:]

    init(liveWorktrees: [WorktreeID] = []) {
        self.liveWorktrees = liveWorktrees
        revisions = Dictionary(uniqueKeysWithValues: liveWorktrees.map { ($0, 1) })
        content = (1...626).map { $0 == 600 ? "changed line 600" : "unchanged line \($0)" }
        let lines = (597...603).flatMap { number -> [DiffLine] in
            if number == 600 {
                return [
                    DiffLine(kind: .deletion, oldNumber: number, newNumber: nil, text: "old line 600", displayColumns: 12, segments: nil),
                    DiffLine(kind: .addition, oldNumber: nil, newNumber: number, text: "changed line 600", displayColumns: 16, segments: nil)
                ]
            }
            let text = "unchanged line \(number)"
            return [DiffLine(kind: .context, oldNumber: number, newNumber: number, text: text, displayColumns: text.count, segments: nil)]
        }
        diff = FileDiff(
            file: FileChange(
                id: FileID(repositoryRelativePath: "Sources/LongFile.swift"),
                path: "Sources/LongFile.swift", oldPath: nil, status: .modified,
                isBinary: false, isSubmodule: false,
                stats: ChangeStats(filesChanged: 1, insertions: 1, deletions: 1),
                contentHash: "trailing-context-content", estimatedLineCount: lines.count,
                isViewed: false, isTruncated: false, language: nil
            ),
            hunks: [Hunk(index: 0, oldStart: 597, oldCount: 7, newStart: 597, newCount: 7, sectionHeading: nil, lines: lines)],
            oldLineCount: 626, newLineCount: 626, isTruncated: false, truncationReason: nil
        )
    }

    func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        reads[worktree, default: 0] += 1
        if liveWorktrees.isEmpty == false {
            let revision = revisions[worktree, default: 1]
            let live = Self.liveDiff(revision: revision)
            return WorktreeChanges(revision: "revision-\(revision)", stats: live.file.stats, files: [live.file], isTruncated: false)
        }
        return WorktreeChanges(revision: "trailing-context-revision", stats: diff.file.stats, files: [diff.file], isTruncated: false)
    }

    func diffs(of files: [FileID], in worktree: WorktreeID, contextLines: Int) async throws(ApiFailure) -> [FileDiff] {
        let current = liveWorktrees.isEmpty ? diff : Self.liveDiff(revision: revisions[worktree, default: 1])
        return files.contains(current.file.id) ? [current] : []
    }

    func lines(of file: FileID, in worktree: WorktreeID, side: DiffSide, start: Int, count: Int) async throws(ApiFailure) -> FileLines {
        guard file == diff.file.id, side == .new, start > 0, start <= content.count else { throw .fileGone }
        let end = min(content.count, start - 1 + count)
        return FileLines(lines: Array(content[(start - 1)..<end]), eof: end == content.count)
    }

    func readCount(in worktree: WorktreeID) -> Int { reads[worktree, default: 0] }

    var subscriptionCount: Int { observers.count }

    func revision(in worktree: WorktreeID) -> Int { revisions[worktree, default: 1] }

    func change(_ worktree: WorktreeID) {
        revisions[worktree, default: 1] += 1
        for observer in observers.values { observer.yield(.snapshot(snapshot())) }
    }

    func updates() async -> AsyncStream<WorktreeUpdate> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<WorktreeUpdate>.makeStream(bufferingPolicy: .bufferingNewest(1))
        guard liveWorktrees.isEmpty == false else {
            continuation.finish()
            return stream
        }
        observers[id] = continuation
        continuation.yield(.snapshot(snapshot()))
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.observers.removeValue(forKey: id) }
        }
        return stream
    }

    func projects() async throws(ApiFailure) -> [Project] { [] }
    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] { snapshot().worktrees }
    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree { throw .worktreeGone }
    func delete(_ worktree: WorktreeID) async throws(ApiFailure) { throw .worktreeGone }
    func image(of file: FileID, in worktree: WorktreeID, side: DiffSide) async throws(ApiFailure) -> Data { throw .fileGone }
    func markViewed(_ viewed: Bool, file: FileID, contentHash: String, in worktree: WorktreeID) async throws(ApiFailure) {}
    func review(in worktree: WorktreeID) async throws(ApiFailure) -> [ReviewComment] { [] }
    func putReview(_ comments: [ReviewComment], in worktree: WorktreeID) async throws(ApiFailure) {}
    func reviewSettings() async throws(ApiFailure) -> ReviewSettings { .unset }
    func updateReviewSettings(_ patch: ReviewSettingsPatch) async throws(ApiFailure) -> ReviewSettings { .unset }

    private func snapshot() -> WorktreeSnapshot {
        WorktreeSnapshot(worktrees: liveWorktrees.map { id in
            let revision = revisions[id, default: 1]
            let name = id == liveWorktrees.first ? "Review A" : "Agent B"
            let alias = id != liveWorktrees.first && revision > 1 ? "Agent B completed" : nil
            return Worktree(
                id: id, projectId: ProjectID(rawValue: "live-project"), projectName: "Live fixture",
                branch: "review", isPrimary: false, isDetached: false, isLocked: false, hasUnbornHead: false,
                alias: alias, suggestedAlias: nil, displayName: alias ?? name, directoryName: name, isPinned: false,
                stats: ChangeStats(filesChanged: 1, insertions: revision, deletions: 0),
                lastModified: Date(timeIntervalSince1970: 1_000), revision: "revision-\(revisions[id, default: 1])"
            )
        }, scannedAt: Date(timeIntervalSince1970: 1_000))
    }

    private static func liveDiff(revision: Int) -> FileDiff {
        let text = "review revision \(revision)"
        let line = DiffLine(kind: .addition, oldNumber: nil, newNumber: 1, text: text, displayColumns: text.count, segments: nil)
        return FileDiff(
            file: FileChange(
                id: FileID(repositoryRelativePath: "Sources/Reader.swift"), path: "Sources/Reader.swift",
                oldPath: nil, status: .added, isBinary: false, isSubmodule: false,
                stats: ChangeStats(filesChanged: 1, insertions: 1, deletions: 0), contentHash: "content-\(revision)",
                estimatedLineCount: 1, isViewed: false, isTruncated: false, language: nil
            ),
            hunks: [Hunk(index: 0, oldStart: 0, oldCount: 0, newStart: 1, newCount: 1, sectionHeading: nil, lines: [line])],
            oldLineCount: 0, newLineCount: 1, isTruncated: false, truncationReason: nil
        )
    }
}
