public enum WorktreeReadStage: Hashable, Sendable {
    case finding(WorktreeConnectionRoutes)
    case verifying
    case reading(WorktreeConnectionRoute)
}

public enum WorktreeConnectionRoutes: Hashable, Sendable {
    case unknown
    case local
    case tailnet
    case localAndTailnet
}

public enum WorktreeConnectionRoute: Hashable, Sendable {
    case unknown
    case local
    case tailnet
}
