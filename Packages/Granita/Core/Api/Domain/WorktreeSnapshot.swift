import Foundation

import CoreDiffDomain

/// A prepared inventory whose age belongs to its oldest successful scan, not its delivery.
public struct WorktreeSnapshot: Hashable, Codable, Sendable {

    public let worktrees: [Worktree]
    public let scannedAt: Date
    public let issues: [WorktreeScanIssue]

    public init(worktrees: [Worktree], scannedAt: Date, issues: [WorktreeScanIssue] = []) {
        self.worktrees = worktrees
        self.scannedAt = scannedAt
        self.issues = issues
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        worktrees = try container.decode([Worktree].self, forKey: .worktrees)
        scannedAt = try container.decode(Date.self, forKey: .scannedAt)
        issues = try container.decodeIfPresent([WorktreeScanIssue].self, forKey: .issues) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case worktrees
        case scannedAt
        case issues
    }
}
