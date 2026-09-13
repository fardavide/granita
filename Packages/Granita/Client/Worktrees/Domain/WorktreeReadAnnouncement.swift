import ClientConnectionDomain

public enum WorktreeReadAnnouncement: Hashable, Sendable {
    case stage(WorktreeReadStage, macName: String)
    case arrived(worktreeCount: Int)
    case refreshFailed

    public var sentence: String {
        switch self {
        case .stage(let stage, let macName):
            let description = WorktreeLoadingDescription(stage: stage, macName: macName, elapsed: 0)
            return "\(description.headline). \(description.sentence)"
        case .arrived(let count): return count == 1 ? "Read 1 worktree." : "Read \(count) worktrees."
        case .refreshFailed: return "Couldn't refresh. Your previous worktrees are still available."
        }
    }
}
