import Foundation

public struct WorktreeRepairPreview: Hashable, Codable, Sendable {
    public let approval: WorktreeRepairApproval
    public let projectName: String
    public let registrations: [String]

    public init(approval: WorktreeRepairApproval, projectName: String, registrations: [String]) {
        self.approval = approval
        self.projectName = projectName
        self.registrations = registrations
    }
}

public struct WorktreeRepairApproval: Hashable, Codable, Sendable {
    public let id: UUID

    public init(id: UUID) {
        self.id = id
    }
}
