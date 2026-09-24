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

    /// No route at all: the worktrees are on the disk this process is running from.
    ///
    /// **Distinct from `local`, which is a network.** `local` means the Mac answered over this
    /// Wi-Fi; this means there was nothing to answer, because the reader and the server are one
    /// bundle and the read is a `git` process rather than a request. Every sentence the other three
    /// carry names a connection, and naming one here would be describing a socket that was never
    /// opened.
    case thisMac
}
