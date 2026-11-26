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
    public let lastRead: LastRead
    private let wireReason: Reason
    // Older readers can still decode a timeout as a Git failure.
    private let timedOut: Bool?

    public var id: WorktreeScanTarget { target }
    public var reason: Reason { timedOut == true ? .gitTimedOut : wireReason }

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
        self.lastRead = lastRead
        let isTimeout = reason == .gitTimedOut
        wireReason = isTimeout ? .gitFailure : reason
        timedOut = isTimeout ? true : nil
    }

    public enum Reason: String, Hashable, Codable, Sendable {
        case gitFailure
        case gitTimedOut
        case staleRegistration
    }

    public enum LastRead: Hashable, Codable, Sendable {
        case never
        case at(Date)
    }

    private enum CodingKeys: String, CodingKey {
        case target, projectID, name, projectName, lastRead, timedOut
        case wireReason = "reason"
    }
}
