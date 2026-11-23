import ClientConnectionDomain
import CoreApiDomain
import CoreDiffDomain

public enum WorktreeScanAction: Hashable, Sendable {
    case idle
    case checking(WorktreeScanTarget)
    case stillUnavailable(WorktreeScanTarget)
    case confirming(WorktreeID, WorktreeRepairPreview)
    case repairing(WorktreeID)
    case failed(WorktreeScanTarget, ApiFailure)

    public var isBusy: Bool {
        switch self {
        case .checking, .confirming, .repairing: true
        case .idle, .stillUnavailable, .failed: false
        }
    }
}
