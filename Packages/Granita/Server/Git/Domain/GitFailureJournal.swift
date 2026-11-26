import Foundation

/// The shareable diagnostics retain fixed command names and error codes.
public actor GitFailureJournal {
    private let capacity: Int
    private let now: @Sendable () -> Date
    private var entries: [String] = []

    public init(capacity: Int, now: @escaping @Sendable () -> Date) {
        self.capacity = capacity
        self.now = now
    }

    public func record(_ error: GitError) {
        let outcome = switch error {
        case .gitUnavailable: "Git could not run"
        case .workingDirectoryUnreadable: "Working directory unreadable"
        case .commandFailed(let command, let exitCode, _): "\(command.diagnosticName) exited \(exitCode)"
        case .terminatedBySignal(let command, let signal, _): "\(command.diagnosticName) stopped by signal \(signal)"
        case .timedOut(let command): "\(command.diagnosticName) timed out"
        }
        entries.append("\(now().ISO8601Format()) \(outcome)")
        if entries.count > capacity { entries.removeFirst(entries.count - capacity) }
    }

    public func report() -> String {
        "Mac-side Git failures\n"
            + (entries.isEmpty ? "No Git failures recorded" : entries.joined(separator: "\n"))
    }
}

private extension GitCommand {
    var diagnosticName: String {
        switch self {
        case .version: "version"
        case .isInsideWorkTree: "isInsideWorkTree"
        case .repositoryRoot: "repositoryRoot"
        case .gitDirectory: "gitDirectory"
        case .commonGitDirectory: "commonGitDirectory"
        case .currentBranch: "currentBranch"
        case .headCommit: "headCommit"
        case .worktrees: "worktrees"
        case .untrackedPaths: "untrackedPaths"
        case .worktreeStatus: "worktreeStatus"
        case .trackedChanges: "trackedChanges"
        case .trackedStats: "trackedStats"
        case .untrackedRenameStats: "untrackedRenameStats"
        case .fileDiff: "fileDiff"
        case .renamedFileDiff: "renamedFileDiff"
        case .untrackedFileDiff: "untrackedFileDiff"
        case .fileContent: "fileContent"
        case .removeWorktree: "removeWorktree"
        case .previewWorktreePrune: "previewWorktreePrune"
        case .hashWorktreeFiles: "hashWorktreeFiles"
        }
    }
}
