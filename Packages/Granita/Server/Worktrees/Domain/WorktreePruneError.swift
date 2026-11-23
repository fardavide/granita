import ServerGitDomain

public enum WorktreePruneError: Error, Hashable, Sendable {
    case git(GitError)
    case previewChanged
    case unavailable
}
