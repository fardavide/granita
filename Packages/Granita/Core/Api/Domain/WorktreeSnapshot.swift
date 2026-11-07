import Foundation

import CoreDiffDomain

/// A prepared inventory whose age belongs to its oldest successful scan, not its delivery.
public struct WorktreeSnapshot: Hashable, Codable, Sendable {

    public let worktrees: [Worktree]
    public let scannedAt: Date

    public init(worktrees: [Worktree], scannedAt: Date) {
        self.worktrees = worktrees
        self.scannedAt = scannedAt
    }
}
