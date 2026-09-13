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
                case .worktrees: .enumeration
                case .currentBranch, .headCommit: .revision
                case .untrackedPaths, .trackedChanges, .trackedStats: .changeMetadata
                case .fileDiff, .untrackedFileDiff, .fileContent: .diffContent
                case .version, .isInsideWorkTree, .repositoryRoot, .removeWorktree: .other
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

    public var text: String {
        let summary = [
            "Enabled projects: \(projectCount)",
            "Worktrees: \(worktreeCount)",
            "Changed files: \(changedFileCount)",
            "Server processing: \(serverDuration)",
            "Git subprocesses: \(gitDuration)"
        ]
        let commands = gitBreakdown.map {
            "\($0.group): \($0.invocationCount) calls, \($0.failedCount) failed, \($0.duration)"
        }
        return (summary + commands + [
            "Offline profile: connection discovery and HTTPS verification are not included."
        ]).joined(separator: "\n")
    }
}

public enum GitCommandGroup: CaseIterable, Hashable, Sendable {
    case status
    case contentHash
    case enumeration
    case revision
    case changeMetadata
    case diffContent
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
