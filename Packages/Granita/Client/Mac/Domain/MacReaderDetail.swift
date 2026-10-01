import ClientWorktreesDomain
import CoreDiffDomain

public enum MacReaderDetail: Hashable, Sendable {
    case blank
    case noWorktreeChosen
    case chosen(WorktreeID, name: String)
    case gone(name: String)

    public init(selection: ReaderWorktreeSelection, sidebar: WorktreeSidebarState, worktrees: [Worktree]) {
        switch (selection, sidebar) {
        case (_, .loading), (_, .failed), (_, .noProjects), (.none, .allQuiet):
            self = .blank
        case (.none, .listing):
            self = .noWorktreeChosen
        case (.chosen(let id, let capturedName), .allQuiet), (.chosen(let id, let capturedName), .listing):
            if let worktree = worktrees.first(where: { $0.id == id }) {
                self = .chosen(id, name: worktree.displayName)
            } else {
                self = .gone(name: capturedName)
            }
        }
    }
}
