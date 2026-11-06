import CoreApiDomain
import CoreDiffDomain

public enum WorktreeRead: Hashable, Sendable {
    case prepared(WorktreeSnapshot)
    case uncached([Worktree])
}
