import Foundation

import ClientConnectionDomain
import CoreDiffDomain
import CoreReviewDomain

/// Serves a bounded file with real line-window semantics to the production reader model.
struct FakeGranitaRepository: GranitaRepository {

    private let diff: FileDiff
    private let content: [String]

    init() {
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
        WorktreeChanges(revision: "trailing-context-revision", stats: diff.file.stats, files: [diff.file], isTruncated: false)
    }

    func diffs(of files: [FileID], in worktree: WorktreeID, contextLines: Int) async throws(ApiFailure) -> [FileDiff] {
        files.contains(diff.file.id) ? [diff] : []
    }

    func lines(of file: FileID, in worktree: WorktreeID, side: DiffSide, start: Int, count: Int) async throws(ApiFailure) -> FileLines {
        guard file == diff.file.id, side == .new, start > 0, start <= content.count else { throw .fileGone }
        let end = min(content.count, start - 1 + count)
        return FileLines(lines: Array(content[(start - 1)..<end]), eof: end == content.count)
    }

    func projects() async throws(ApiFailure) -> [Project] { [] }
    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] { [] }
    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree { throw .worktreeGone }
    func delete(_ worktree: WorktreeID) async throws(ApiFailure) { throw .worktreeGone }
    func image(of file: FileID, in worktree: WorktreeID, side: DiffSide) async throws(ApiFailure) -> Data { throw .fileGone }
    func markViewed(_ viewed: Bool, file: FileID, contentHash: String, in worktree: WorktreeID) async throws(ApiFailure) {}
    func review(in worktree: WorktreeID) async throws(ApiFailure) -> [ReviewComment] { [] }
    func putReview(_ comments: [ReviewComment], in worktree: WorktreeID) async throws(ApiFailure) {}
    func reviewSettings() async throws(ApiFailure) -> ReviewSettings { .unset }
    func updateReviewSettings(_ patch: ReviewSettingsPatch) async throws(ApiFailure) -> ReviewSettings { .unset }
}
