/// A question this product asks git.
///
/// The list is closed on purpose. Every invocation the product makes is one of these cases, so the
/// flags each one needs — and the traps each one has — are settled in one place rather than at each
/// call site, and a backend that is not a subprocess can implement the same vocabulary.
public enum GitCommand: Hashable, Sendable {

    /// Whether this directory is inside a checkout at all.
    case isInsideWorkTree

    /// The absolute path of the checkout's root.
    case repositoryRoot

    /// The current branch, or the literal `HEAD` when the checkout is detached.
    case currentBranch

    /// The commit `HEAD` names, if it names one.
    ///
    /// A repository with no commits yet answers with nothing rather than failing, which is how a
    /// caller learns to substitute ``GitRevision/emptyTree`` everywhere it would have said
    /// ``GitRevision/head``.
    case headCommit

    /// Every checkout of this repository — the primary one and each linked worktree.
    case worktrees

    /// The files present but not tracked, with everything the ignore rules exclude left out.
    case untrackedPaths

    /// The state of the checkout, used for its revision and for which paths are conflicted, and for
    /// nothing else.
    ///
    /// Deliberately not the source of the change set: this comparison is HEAD to index and index to
    /// working tree, while the change set's is HEAD to working tree, and the two detect renames
    /// differently often enough that mixing them produces files with no stats and totals that do
    /// not add up.
    case worktreeStatus

    /// Which tracked paths changed, and what happened to each.
    case trackedChanges(against: GitRevision)

    /// How much each tracked path changed by.
    ///
    /// The same comparison as ``trackedChanges(against:)`` with the same rename threshold, which is
    /// what makes the two agree by construction rather than by coincidence.
    case trackedStats(against: GitRevision)

    /// One tracked file's diff, with the given number of context lines around each change.
    case fileDiff(path: RepositoryRelativePath, against: GitRevision, contextLines: Int)

    /// One untracked file's diff, rendered as a full addition.
    case untrackedFileDiff(path: RepositoryRelativePath, contextLines: Int)

    /// A file's content as of a revision, which is the side of it the working tree replaced.
    case fileContent(path: RepositoryRelativePath, at: GitRevision)
}

/// The side of a comparison that is not the working tree.
public enum GitRevision: Hashable, Sendable {

    /// The commit currently checked out.
    case head

    /// Git's empty tree.
    ///
    /// Substituted for ``head`` in a repository with no commits, where `git diff HEAD` fails
    /// outright while every other command carries on. Comparing against the empty tree renders the
    /// whole checkout as an addition, which is what a first commit's worth of work is.
    case emptyTree
}
