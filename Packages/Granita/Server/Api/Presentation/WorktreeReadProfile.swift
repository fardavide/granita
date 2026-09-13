import CoreDiffDomain
import ServerGitDomain

public struct WorktreeReadProfile: Sendable {

    public let projectCount: Int
    public let worktreeCount: Int
    public let changedFileCount: Int
    public let serverDuration: Duration
    public let gitDuration: Duration
    public let gitBreakdown: [GitCommandProfile]

    public init(
        worktrees: [Worktree],
        enabledProjectCount: Int,
        duration: Duration,
        gitMeasurements: [GitCommandMeasurement]
    ) {
        projectCount = enabledProjectCount
        worktreeCount = worktrees.count
        changedFileCount = worktrees.reduce(0) { $0 + $1.stats.filesChanged }
        serverDuration = duration
        gitDuration = gitMeasurements.reduce(.zero) { $0 + $1.duration }
        gitBreakdown = GitCommandGroup.allCases.compactMap { group in
            let measurements = gitMeasurements.filter { measurement in
                let measuredGroup: GitCommandGroup = switch measurement.command {
                case .worktreeStatus: .status
                case .hashWorktreeFiles: .contentHash
                case .version, .isInsideWorkTree, .repositoryRoot, .currentBranch, .headCommit,
                     .worktrees, .untrackedPaths, .trackedChanges, .trackedStats, .fileDiff,
                     .untrackedFileDiff, .fileContent, .removeWorktree: .other
                }
                return measuredGroup == group
            }
            guard measurements.isEmpty == false else { return nil }
            return GitCommandProfile(
                group: group,
                invocationCount: measurements.count,
                failedCount: measurements.filter { $0.outcome == .failed }.count,
                duration: measurements.reduce(.zero) { $0 + $1.duration }
            )
        }
    }
}

public enum GitCommandGroup: CaseIterable, Hashable, Sendable {
    case status
    case contentHash
    case other
}

public struct GitCommandProfile: Hashable, Sendable {

    public let group: GitCommandGroup
    public let invocationCount: Int
    public let failedCount: Int
    public let duration: Duration

    public init(group: GitCommandGroup, invocationCount: Int, failedCount: Int, duration: Duration) {
        self.group = group
        self.invocationCount = invocationCount
        self.failedCount = failedCount
        self.duration = duration
    }
}
