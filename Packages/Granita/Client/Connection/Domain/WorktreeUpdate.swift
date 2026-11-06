import CoreApiDomain

public enum WorktreeUpdate: Hashable, Sendable {
    case snapshot(WorktreeSnapshot)
    case failed(ApiFailure)
    case unsupported
}
