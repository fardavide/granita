/// The codes the client branches on.
///
/// Part of the wire contract rather than an implementation detail: the phone shows a different
/// screen for several of these, so adding one is a contract change and renaming one is a version
/// skew that reaches a reader as a screen that never appears.
///
/// A `Core` type because both halves name it. The Mac writes these strings and the phone switches on
/// them, and two enumerations of one list is exactly how a rename becomes a refusal the phone
/// silently cannot read. The HTTP status each maps to is the Mac's business and stays there.
public enum ApiErrorCode: String, Codable, Hashable, Sendable, CaseIterable {

    case unauthorized

    /// A pairing code that has expired **or** never existed. One code for both on purpose: a caller
    /// told which it was has an oracle for whether it is guessing in the right shape at all.
    case pairingExpired

    case rateLimited

    /// The project exists but the user has not enabled it. Distinct from "not found" on purpose:
    /// the server declines to say whether an identifier it will not serve corresponds to anything.
    case projectNotVisible

    /// The worktree's directory or its entry in git is gone — an agent removed it while it was
    /// being read, which is ordinary rather than exceptional.
    case worktreeGone

    /// The worktree is there and this Mac will not take it away — it is the project's primary
    /// checkout, or somebody locked it.
    ///
    /// Distinct from ``worktreeGone`` because the reader can do nothing about that one and something
    /// about this one, and distinct from ``gitFailure`` because these two refusals are predictable
    /// from what the Mac already knows rather than discovered by running git and reading its words.
    case worktreeNotDeletable

    case fileGone

    /// The file changed since the reader marked it viewed, so the mark would be over a version
    /// nobody saw.
    case staleContentHash

    /// Carries git's own standard error, because nothing else makes a git failure diagnosable from
    /// a phone three rooms away.
    case gitFailure

    case tooLarge
    case badRequest

    /// The client speaks a newer version of this API than the Mac serves.
    case unsupportedApiVersion
}
