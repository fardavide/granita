/// Every way a request to a Mac can fail, in the vocabulary the phone reasons in.
///
/// **No HTTP status code reaches this type, and none reaches anything above it.** SPEC §8 makes the
/// error *codes* the contract precisely because the client branches on them; a status is how one of
/// them travelled, and a screen that switched on `401` would be a screen that had to know the
/// difference between two refusals the Mac deliberately spells the same way.
///
/// The two cases at the bottom are not in §8 because §8 describes what a Mac says. These are what
/// happens when it says nothing, or says something this version was not taught.
public enum ApiFailure: Error, Hashable, Sendable {

    /// No token, or a token this Mac did not issue. The phone has to pair again.
    case unauthorized

    /// The pairing code was refused. **The Mac does not say whether it never existed or merely
    /// expired, and this must not pretend to know** — telling those apart hands an unauthenticated
    /// caller an oracle for whether it is guessing in the right shape at all.
    case pairingExpired

    /// Five failures in a minute from this address. Waiting is the whole remedy.
    case rateLimited

    /// The project exists and has not been enabled. Distinct from "not found" on purpose: the Mac
    /// declines to say whether an identifier it will not serve corresponds to anything.
    case projectNotVisible

    /// The worktree's directory or its entry in git went away while it was being read. Ordinary
    /// rather than exceptional — an agent removes one every day.
    case worktreeGone

    case fileGone

    /// The file changed since the reader saw it, so the mark would be over a version nobody read.
    case staleContentHash

    /// git's own standard error, verbatim. It is the only thing that makes a git failure
    /// diagnosable from a phone three rooms away, and the reader of this app wrote it.
    case gitFailure(message: String)

    case tooLarge

    /// The Mac refused the request as malformed, which is this app's bug rather than the reader's.
    case badRequest(message: String)

    /// This phone speaks a newer contract than that Mac serves. Nothing to retry: the Mac app is
    /// behind and has to be updated.
    case unsupportedApiVersion

    /// This app could not build the request, so nothing reached the Mac and retrying will not help.
    ///
    /// A bug here rather than anything about the network, and the diagnostic is for whoever fixes
    /// it. It exists so that no step of assembling a request has to be silenced with a `try?`.
    case requestNotBuildable(diagnostic: String)

    /// The Mac could not be reached at all, carrying what the system said.
    ///
    /// A **diagnostic**, not advice, and the label says so: the screen writes its own sentence and
    /// prints this underneath in small print. `URLError`'s own words are "the operation couldn't be
    /// completed", which is true of every failure there has ever been and actionable in none.
    case unreachable(diagnostic: String)

    /// The Mac answered with something this version cannot read — a body that is not the shape the
    /// contract describes, or a refusal code a newer Mac invented.
    ///
    /// One case for both, because the reader can do nothing different about them and the diagnostic
    /// is what tells the developer which it was.
    case notUnderstood(diagnostic: String)

    /// The machine's own words, where there are any, for the small print under a screen's own
    /// sentence.
    ///
    /// **Never advice, and never the description slot** — that slot is ours on every screen in this
    /// app. What comes back here is copyable into a bug report and unmistakably not instructions,
    /// which is the whole reason it is separated from the sentence a reader is meant to act on.
    ///
    /// `nil` for the refusals a Mac spells deliberately: those are answers rather than faults, and
    /// printing "unauthorized" under a sentence that already says so is noise with a monospaced
    /// font on it.
    public var diagnostic: String? {
        switch self {
        case .unauthorized, .pairingExpired, .rateLimited, .projectNotVisible: nil
        case .worktreeGone, .fileGone, .staleContentHash, .tooLarge, .unsupportedApiVersion: nil
        case .gitFailure(let message): message
        case .badRequest(let message): message
        case .requestNotBuildable(let diagnostic): diagnostic
        case .unreachable(let diagnostic): diagnostic
        case .notUnderstood(let diagnostic): diagnostic
        }
    }
}
