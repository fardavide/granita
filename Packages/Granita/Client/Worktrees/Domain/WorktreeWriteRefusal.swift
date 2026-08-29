import ClientConnectionDomain

/// A write the Mac refused, and which write it was.
///
/// **The operation travels with the failure, because the same `ApiFailure` means two different
/// things.** An unreachable Mac leaves a rename exactly as it was, so *trying again usually works*
/// is true. It leaves a deletion in a state this phone cannot describe — the request may have
/// arrived and the answer may have been lost — so the same sentence would be a claim nobody can
/// make about a worktree that may already be gone.
///
/// Two cases rather than one per write: renaming and pinning are the same promise to a reader, and
/// telling them apart would be a distinction with no different sentence behind it.
public enum WorktreeWriteRefusal: Hashable, Sendable {

    /// A rename or a pin. The row is exactly as it was.
    case edit(ApiFailure)

    /// A deletion. What the row shows may no longer be true.
    case deletion(ApiFailure)
}
