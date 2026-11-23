import Foundation

import CoreDiffDomain

public enum WorktreeScanTarget: Hashable, Codable, Sendable {
    case project(ProjectID)
    case worktree(WorktreeID)
}

public struct WorktreeScanIssue: Identifiable, Hashable, Codable, Sendable {
    public let target: WorktreeScanTarget
    public let projectID: ProjectID
    public let name: String
    public let projectName: String
    public let reason: Reason
    public let lastRead: LastRead

    public var id: WorktreeScanTarget { target }

    public init(
        target: WorktreeScanTarget,
        projectID: ProjectID,
        name: String,
        projectName: String,
        reason: Reason,
        lastRead: LastRead
    ) {
        self.target = target
        self.projectID = projectID
        self.name = name
        self.projectName = projectName
        self.reason = reason
        self.lastRead = lastRead
    }

    public enum Reason: String, Hashable, Codable, Sendable {
        case gitFailure
        case staleRegistration
    }

    public enum LastRead: Hashable, Codable, Sendable {
        case never
        case at(Date)
    }
}
