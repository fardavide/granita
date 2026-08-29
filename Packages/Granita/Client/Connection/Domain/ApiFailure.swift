import Foundation

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

    /// The worktree is there and the Mac will not take it away: it is the project's own checkout,
    /// or somebody locked it. The Mac's sentence says which.
    ///
    /// Not a fault and not something to retry — the reader has to do something on the Mac, or the
    /// row should never have offered the control. Both are true at once, which is why the phone
    /// decides deletability from the row it already has and this exists behind it anyway.
    case worktreeNotDeletable(message: String)

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

    /// **This phone called the request off, so nothing failed.**
    ///
    /// A `.task` is cancelled the moment its view goes away, which in a navigation stack is every
    /// time the reader opens something — so an in-flight read is routinely torn down by the app
    /// itself. Folded into `unreachable` it became *Could not read your Mac*, with `NSURLErrorDomain
    /// Code=-999 "cancelled"` in the small print: the app blaming the Mac for something the app did,
    /// on a screen the reader reached by pressing Back. Seen on a real iPhone.
    ///
    /// It is a case rather than a `nil` return because the transport cannot decide what to do about
    /// it and the screen can: a model that was still loading has simply stopped, and the right screen
    /// is the one that was already there.
    case cancelled

    /// The Mac answered with something this version cannot read — a body that is not the shape the
    /// contract describes, or a refusal code a newer Mac invented.
    ///
    /// One case for both, because the reader can do nothing different about them and the diagnostic
    /// is what tells the developer which it was.
    case notUnderstood(diagnostic: String)

    /// What a failure from the transport means to this app.
    ///
    /// **A rule rather than a `catch` block**, and it lives here for the reason every other rule in
    /// this repository moved out of the thing that spends it: a `URLSession` cannot be built in a
    /// test binary, so a decision written inside the transport is a decision nothing holds to its
    /// behaviour — and the decision it was hiding was wrong. `NSURLErrorCancelled` was folded into
    /// `unreachable`, which put *Could not read your Mac* on the screen a reader reached by pressing
    /// Back.
    ///
    /// The order matters: a failure this layer already understands passes through untouched, a
    /// cancellation is not a failure at all, and everything else is the Mac being out of reach with
    /// the system's own words kept as small print.
    public static func forTransport(_ error: any Error) -> ApiFailure {
        switch error {
        case let failure as ApiFailure:
            failure
        case is CancellationError:
            .cancelled
        case let url as URLError where url.code == .cancelled:
            .cancelled
        default:
            // The diagnostic, not the advice. `URLError` writes "the operation couldn't be
            // completed", which is true of every failure there has ever been; the screen supplies
            // the sentence and prints this underneath in small print.
            .unreachable(diagnostic: "\(error)")
        }
    }

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
        // Nothing to print, because nothing is meant to be on screen: a cancelled read leaves the
        // screen the reader was already looking at.
        case .cancelled: nil
        case .gitFailure(let message): message
        case .badRequest(let message): message
        // The Mac's own sentence names which of the two refusals it was, and the screen has no
        // second way to find out — so this one is small print with something in it rather than nil.
        case .worktreeNotDeletable(let message): message
        case .requestNotBuildable(let diagnostic): diagnostic
        case .unreachable(let diagnostic): diagnostic
        case .notUnderstood(let diagnostic): diagnostic
        }
    }
}
