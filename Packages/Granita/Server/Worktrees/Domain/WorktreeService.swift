import Foundation

import CoreDiffDomain
import ServerGitDomain

/// What a worktree's uncommitted state is, assembled from git.
///
/// The one rule this type exists to keep: **the tracked change set and its stats come from a single
/// comparison with identical options.** Taking the file list from the merge state and the stats
/// from a diff runs rename detection twice over two different comparisons — one is HEAD to index
/// and index to working tree, the other is HEAD to working tree — and they disagree often enough
/// that the result is files with no stats, stats with no file, and totals that do not add up. The
/// merge state is read here for exactly two things it alone knows: which paths are conflicted, and
/// what the whole worktree's revision is.
public struct WorktreeService: Sendable {

    private let git: any GitClient
    private let limits: WorktreeLimits

    public init(git: any GitClient, limits: WorktreeLimits) {
        self.git = git
        self.limits = limits
    }

    public func worktrees(in project: RepositoryLocation) async throws(GitError) -> [WorktreeRecord] {
        WorktreeListParser.parse(try await git.run(.worktrees, in: project).standardOutput)
    }

    /// Whether this worktree's HEAD names a commit yet.
    ///
    /// Resolved once per refresh and threaded through everything that follows, because a repository
    /// with no commits fails every comparison against `HEAD` while answering every other command
    /// normally — which is what a project on its first day looks like.
    public func revisionToCompareAgainst(
        in worktree: RepositoryLocation
    ) async throws(GitError) -> GitRevision {
        let head = try await git.run(.headCommit, in: worktree).standardOutput
        return head.isEmpty ? .emptyTree : .head
    }

    public func changeSet(
        in worktree: RepositoryLocation,
        viewed: [FileID: String]
    ) async throws(GitError) -> WorktreeChangeSet {
        let revision = try await revisionToCompareAgainst(in: worktree)

        let statusBytes = try await git.run(.worktreeStatus, in: worktree).standardOutput
        let conflicted = StatusParser.conflictedPaths(statusBytes)

        let changes = RawChangeParser.parse(
            try await git.run(.trackedChanges(against: revision), in: worktree).standardOutput
        )
        let numbers = NumstatParser.parse(
            try await git.run(.trackedStats(against: revision), in: worktree).standardOutput
        )
        let untracked = UntrackedPathParser.parse(
            try await git.run(.untrackedPaths, in: worktree).standardOutput
        )

        // A trailing separator is git declining to look inside: `ls-files --others` reports a
        // nested repository or worktree as one directory entry rather than descending into it.
        // Claude Code puts every worktree it creates under `.claude/worktrees/`, so the primary
        // checkout of any project an agent has touched has one — and it is not a file. Shown as
        // one it is an added file nobody can open, and hashing it fails the **whole** batch rather
        // than its own line, which takes the entire change set down with it.
        let entries = tracked(changes, statsBy: numbers, conflicted: conflicted)
            + untracked.filter { $0.text.hasSuffix("/") == false }.map(Entry.untracked)
        let kept = Array(entries.prefix(limits.maximumChangedFiles))
        let worktreeObjectIds = try await worktreeObjectIds(for: kept, in: worktree)

        var files: [FileChange] = []
        var paths: [FileID: RepositoryRelativePath] = [:]
        var oldPaths: [FileID: RepositoryRelativePath] = [:]
        var total = ChangeStats.zero
        for (index, entry) in kept.enumerated() {
            let id = FileID(repositoryRelativePathBytes: entry.path.bytes)
            let contentHash = ContentHash.forFile(
                status: entry.status,
                headObjectId: entry.headObjectId,
                indexObjectId: entry.indexObjectId,
                worktreeObjectId: worktreeObjectIds.indices.contains(index)
                    ? worktreeObjectIds[index]
                    : ContentHash.absentObjectId
            )
            files.append(FileChange(
                id: id,
                path: entry.path.text,
                oldPath: entry.oldPath?.text,
                status: entry.status,
                isBinary: entry.isBinary,
                isSubmodule: entry.isSubmodule,
                stats: entry.stats,
                contentHash: contentHash,
                estimatedLineCount: entry.stats.insertions + entry.stats.deletions,
                isViewed: viewed[id] == contentHash,
                isTruncated: entry.stats.insertions + entry.stats.deletions > limits.maximumDiffLines,
                language: LanguageHint.forPath(entry.path.text)
            ))
            paths[id] = entry.path
            oldPaths[id] = entry.oldPath
            total = total + entry.stats
        }

        return WorktreeChangeSet(
            revision: ContentHash.revision(ofStatusBytes: statusBytes),
            stats: total,
            files: files,
            isTruncated: entries.count > limits.maximumChangedFiles,
            paths: paths,
            oldPaths: oldPaths
        )
    }

    /// One file's diff, with the size guards applied.
    ///
    /// An untracked file has no side in the revision, so it is compared against the null device
    /// instead — a comparison that exits 1 every time, which for this family is success.
    public func fileDiff(
        for file: FileChange,
        at path: RepositoryRelativePath,
        in worktree: RepositoryLocation,
        contextLines: Int
    ) async throws(GitError) -> FileDiff {
        let revision = try await revisionToCompareAgainst(in: worktree)
        let command: GitCommand = file.status == .untracked
            ? .untrackedFileDiff(path: path, contextLines: contextLines)
            : .fileDiff(path: path, against: revision, contextLines: contextLines)

        let output = try await git.run(command, in: worktree)
        let text = String(decoding: output.standardOutput, as: UTF8.self)
        let parsed = UnifiedDiffParser.parse(text).first

        var hunks = parsed?.hunks ?? []
        let lineCount = hunks.reduce(0) { $0 + $1.lines.count }
        var truncationReason: String?

        if output.isTruncated {
            truncationReason = "the diff is larger than this worktree serves in one piece"
        } else if lineCount > limits.maximumDiffLines {
            truncationReason = "the diff is \(lineCount) lines; showing the first \(limits.truncatedDiffLines)"
        }
        if truncationReason != nil {
            hunks = Self.firstLines(of: hunks, upTo: limits.truncatedDiffLines)
        }

        return FileDiff(
            file: file,
            hunks: hunks,
            oldLineCount: hunks.last.map { $0.oldStart + $0.oldCount - 1 } ?? 0,
            newLineCount: hunks.last.map { $0.newStart + $0.newCount - 1 } ?? 0,
            isTruncated: truncationReason != nil,
            truncationReason: truncationReason
        )
    }

    /// The raw lines of one side of a file, which is what context expansion is spliced from.
    ///
    /// Expansion is client-owned state: a single stateless parameter cannot say "hunk two expanded
    /// upwards and hunk five expanded downwards", so the client asks for lines and does the
    /// splicing itself.
    public func lines(
        of path: RepositoryRelativePath,
        side: DiffSide,
        start: Int,
        count: Int,
        in worktree: RepositoryLocation
    ) async throws(GitError) -> (lines: [String], isAtEnd: Bool) {
        let text: String
        switch side {
        case .old:
            let revision = try await revisionToCompareAgainst(in: worktree)
            text = String(decoding: try await git.run(
                .fileContent(path: path, at: revision),
                in: worktree
            ).standardOutput, as: UTF8.self)
        case .new:
            // The working copy is not in the object database, so there is no revision to read it
            // from; it is compared against nothing and the additions are its content.
            let output = try await git.run(.untrackedFileDiff(path: path, contextLines: 0), in: worktree)
            text = String(decoding: output.standardOutput, as: UTF8.self)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { $0.hasPrefix("+") && $0.hasPrefix("+++") == false }
                .map { String($0.dropFirst()) }
                .joined(separator: "\n")
        }

        let all = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let from = max(0, start - 1)
        guard from < all.count else { return ([], true) }
        let to = min(all.count, from + count)
        return (Array(all[from..<to]), to >= all.count)
    }

    // MARK: - Assembly

    private func tracked(
        _ changes: [RawChange],
        statsBy numbers: [NumstatRecord],
        conflicted: Set<RepositoryRelativePath>
    ) -> [Entry] {
        let byPath = Dictionary(numbers.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        return changes.map { change in
            let record = byPath[change.path]
            return Entry(
                path: change.path,
                oldPath: change.oldPath,
                status: conflicted.contains(change.path) ? .conflicted : change.status,
                stats: ChangeStats(
                    filesChanged: 1,
                    insertions: record?.insertions ?? 0,
                    deletions: record?.deletions ?? 0
                ),
                // A dash where a count should be is git saying it did not diff the content.
                isBinary: record.map { $0.insertions == nil && $0.deletions == nil } ?? false,
                isSubmodule: change.isSubmodule,
                headObjectId: change.oldObjectId,
                indexObjectId: change.newObjectId
            )
        }
    }

    private func worktreeObjectIds(
        for entries: [Entry],
        in worktree: RepositoryLocation
    ) async throws(GitError) -> [String] {
        // Two kinds of entry have no working-tree blob: a file that is gone, and a submodule,
        // which is a directory as far as this Mac is concerned. Either one fails the **whole**
        // batch rather than its own line, so both are left out and take the absent id.
        let present = entries.filter { $0.hasWorktreeBlob }
        guard present.isEmpty == false else { return entries.map { _ in ContentHash.absentObjectId } }

        let output = try await git.run(
            .hashWorktreeFiles(paths: present.map(\.path)),
            in: worktree
        ).standardOutput
        var hashed = String(decoding: output, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .makeIterator()

        return entries.map { entry in
            entry.hasWorktreeBlob ? (hashed.next() ?? ContentHash.absentObjectId) : ContentHash.absentObjectId
        }
    }

    /// Keeps whole hunks up to a line budget, so a truncated diff never ends mid-hunk.
    private static func firstLines(of hunks: [Hunk], upTo budget: Int) -> [Hunk] {
        var kept: [Hunk] = []
        var used = 0
        for hunk in hunks where used < budget {
            kept.append(hunk)
            used += hunk.lines.count
        }
        return kept
    }

    private struct Entry {
        let path: RepositoryRelativePath
        let oldPath: RepositoryRelativePath?
        let status: FileStatus
        let stats: ChangeStats
        let isBinary: Bool
        let isSubmodule: Bool
        let headObjectId: String
        let indexObjectId: String

        var hasWorktreeBlob: Bool { status != .deleted && isSubmodule == false }

        static func untracked(_ path: RepositoryRelativePath) -> Entry {
            Entry(
                path: path,
                oldPath: nil,
                status: .untracked,
                stats: ChangeStats(filesChanged: 1, insertions: 0, deletions: 0),
                isBinary: false,
                isSubmodule: false,
                headObjectId: ContentHash.absentObjectId,
                indexObjectId: ContentHash.absentObjectId
            )
        }
    }
}

/// Which side of a comparison raw lines are read from.
public enum DiffSide: String, Codable, Hashable, Sendable, CaseIterable {
    case old
    case new
}

/// A worktree's uncommitted state.
public struct WorktreeChangeSet: Hashable, Sendable {

    /// Moves whenever anything about the worktree moves, and is what the phone polls.
    public let revision: String

    public let stats: ChangeStats
    public let files: [FileChange]

    /// Whether more files changed than this worktree serves at once.
    public let isTruncated: Bool

    /// The bytes each file's path had.
    ///
    /// Not on the wire and not part of `FileChange`: a path is bytes, `FileChange.path` is the
    /// lossy decoding of them for display, and re-invoking git on the decoded form would address a
    /// file that does not exist. Anything that goes back to git for one of these files looks the
    /// path up here.
    public let paths: [FileID: RepositoryRelativePath]

    /// Where a renamed file used to be.
    ///
    /// Its own map because the two sides of a rename live at two paths, and the committed side is
    /// only readable at the old one — `show HEAD:<new path>` fails outright, which is what
    /// expanding context above a hunk in a renamed file would do on every attempt.
    public let oldPaths: [FileID: RepositoryRelativePath]

    public init(
        revision: String,
        stats: ChangeStats,
        files: [FileChange],
        isTruncated: Bool,
        paths: [FileID: RepositoryRelativePath],
        oldPaths: [FileID: RepositoryRelativePath]
    ) {
        self.revision = revision
        self.stats = stats
        self.files = files
        self.isTruncated = isTruncated
        self.paths = paths
        self.oldPaths = oldPaths
    }
}

/// SPEC §5.4's ceilings, so a repository nobody expected cannot take the Mac down.
public struct WorktreeLimits: Hashable, Sendable {

    public let maximumChangedFiles: Int
    public let maximumDiffLines: Int
    public let truncatedDiffLines: Int

    public init(maximumChangedFiles: Int, maximumDiffLines: Int, truncatedDiffLines: Int) {
        self.maximumChangedFiles = maximumChangedFiles
        self.maximumDiffLines = maximumDiffLines
        self.truncatedDiffLines = truncatedDiffLines
    }

    public static let standard = WorktreeLimits(
        maximumChangedFiles: 1_000,
        maximumDiffLines: 20_000,
        truncatedDiffLines: 2_000
    )
}
