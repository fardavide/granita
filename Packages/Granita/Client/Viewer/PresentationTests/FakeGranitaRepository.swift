import Foundation
import Synchronization

import ClientConnectionDomain
import ClientViewerDomain
import CoreDiffDomain

/// A Mac that answers the two read routes the diff screen uses, and records what it was asked for.
///
/// **The requests are what most of this suite asserts.** `SPEC.md` §10's rule is about *which* files
/// are fetched and in what order, so a fake that only answered would leave the whole of it untested:
/// the assertion is the batch that left the phone, not the hunks that came back.
final class FakeGranitaRepository: GranitaRepository {

    /// Every batch of file identifiers asked for, in order. One entry per `/diffs` request, so a
    /// batch that should have been skipped is visible as an extra entry rather than as a count.
    var batchesAskedFor: [[FileID]] { batches.withLock { $0 } }

    /// Every mark written, in order, with the hash it was written against — which is the field the
    /// Mac refuses on, and therefore the one worth asserting rather than assuming.
    var viewedWrites: [ViewedWrite] { writes.withLock { $0 } }

    /// Every window of raw lines asked for, in order. The window is the whole of what the client
    /// decides about expansion, so it is the thing worth recording rather than the text.
    var windowsAskedFor: [LineWindow] { windows.withLock { $0 } }

    private let changeSet: Result<WorktreeChanges, ApiFailure>

    /// What the first read answers with, when the point of the test is what the second one does.
    private let refusesTheFirstRead: ApiFailure?

    private let reads = Mutex<Int>(0)
    private let hunks: [FileID: [Hunk]]
    private let diffFailure: ApiFailure?
    private let viewedFailure: ApiFailure?
    private let linesAnswer: Result<FileLines, ApiFailure>

    /// A file the change set never named, answered alongside the ones that were asked for.
    ///
    /// Not a contrivance: the worktree moves while the phone reads it, so a batch asked for against
    /// one revision can be answered against the next.
    private let stranger: FileChange?

    private let batches = Mutex<[[FileID]]>([])
    private let writes = Mutex<[ViewedWrite]>([])
    private let windows = Mutex<[LineWindow]>([])

    init(
        changeSet: Result<WorktreeChanges, ApiFailure>,
        hunks: [FileID: [Hunk]] = [:],
        diffFailure: ApiFailure? = nil,
        viewedFailure: ApiFailure? = nil,
        linesAnswer: Result<FileLines, ApiFailure> = .failure(.fileGone),
        refusesTheFirstRead: ApiFailure? = nil,
        alsoAnswering stranger: FileChange? = nil
    ) {
        self.changeSet = changeSet
        self.hunks = hunks
        self.diffFailure = diffFailure
        self.viewedFailure = viewedFailure
        self.linesAnswer = linesAnswer
        self.refusesTheFirstRead = refusesTheFirstRead
        self.stranger = stranger
    }

    /// **Refuses the first read and answers afterwards when asked to**, which is the only way to put
    /// one model through a failure and then a retry — and the retry is what a reader presses when a
    /// screen has gone wrong, so it is the path worth holding to its behaviour.
    func changes(in worktree: WorktreeID) async throws(ApiFailure) -> WorktreeChanges {
        let isFirst = reads.withLock { count in
            count += 1
            return count == 1
        }
        if let refusesTheFirstRead, isFirst {
            throw refusesTheFirstRead
        }
        return try changeSet.get()
    }

    func diffs(
        of files: [FileID],
        in worktree: WorktreeID,
        contextLines: Int
    ) async throws(ApiFailure) -> [FileDiff] {
        batches.withLock { $0.append(files) }
        if let diffFailure { throw diffFailure }
        guard case .success(let changes) = changeSet else { return [] }
        let asked = files.compactMap { file in
            changes.files.first { $0.id == file }
        }
        return (asked + [stranger].compactMap { $0 }).map { change in
            FileDiff(
                file: change,
                hunks: hunks[change.id] ?? [],
                oldLineCount: change.estimatedLineCount,
                newLineCount: change.estimatedLineCount,
                isTruncated: false,
                truncationReason: nil
            )
        }
    }

    func lines(
        of file: FileID,
        in worktree: WorktreeID,
        side: DiffSide,
        start: Int,
        count: Int
    ) async throws(ApiFailure) -> FileLines {
        windows.withLock { $0.append(LineWindow(side: side, start: start, count: count)) }
        return try linesAnswer.get()
    }

    // MARK: - Not reached from the diff screen

    func projects() async throws(ApiFailure) -> [Project] { [] }

    func worktrees(inProject project: ProjectID?) async throws(ApiFailure) -> [Worktree] { [] }

    func update(_ worktree: WorktreeID, with patch: WorktreePatch) async throws(ApiFailure) -> Worktree {
        throw .worktreeGone
    }

    func delete(_ worktree: WorktreeID) async throws(ApiFailure) {
        throw .worktreeGone
    }

    func markViewed(
        _ viewed: Bool,
        file: FileID,
        contentHash: String,
        in worktree: WorktreeID
    ) async throws(ApiFailure) {
        writes.withLock { $0.append(ViewedWrite(isViewed: viewed, file: file, contentHash: contentHash)) }
        if let viewedFailure { throw viewedFailure }
    }
}

// MARK: -

/// One mark, as it left the phone.
struct ViewedWrite: Hashable, Sendable {

    let isViewed: Bool
    let file: FileID
    let contentHash: String
}
