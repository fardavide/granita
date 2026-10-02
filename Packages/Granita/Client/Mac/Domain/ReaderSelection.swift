import ClientConnectionDomain
import CoreDiffDomain

public enum ReaderSource: Hashable, Sendable {
    case thisMac
    case remote(DiscoveredServer)
}

public enum ReaderWorktreeSelection: Hashable, Sendable {
    case none
    case chosen(WorktreeID, name: String)
}

public struct ReaderSelection: Hashable, Sendable {
    public let source: ReaderSource
    public let worktree: ReaderWorktreeSelection

    public init(source: ReaderSource, worktree: ReaderWorktreeSelection) {
        self.source = source
        self.worktree = worktree
    }
}

public protocol ReaderSelectionMemory: Sendable {
    func read() -> ReaderSelection
    func remember(_ selection: ReaderSelection)
}
