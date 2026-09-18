import ClientConnectionDomain

/// What the bar at the bottom of the diff says when files could not be read, and which control it
/// offers.
///
/// **The statement is per file and the recovery is per request**, which is design §9's call 6.2 cut
/// along the line between *news* and *remedy*. Five files are blank, so five cards say why; one
/// request failed, so one control retries it. Neither half is redundant — take the rows away and
/// five cards go quiet again, take the bar away and the reader is told five times about something
/// they cannot act on.
///
/// **The control is chosen by the failure rather than offered regardless**, and that is a safety
/// property rather than a nicety: a revoked pairing makes every later request fail too, so a *Try
/// Again* there is a control that cannot work. With a per-file retry it would have been that dead
/// control drawn once per blank card.
public struct DiffBatchFailure: Hashable, Sendable {

    /// The one move the reader has, which is one of exactly three.
    ///
    /// It is an enum rather than a label and a closure because the *choice* is the design's and the
    /// wiring is the screen's — and because a control whose words are decided in one place and whose
    /// action is decided in another is how a screen ends up offering *Pair Again* and running a
    /// retry.
    public enum Remedy: Hashable, Sendable {

        case tryAgain
        case backToWorktrees
        case pairAgain

        public var label: String {
            switch self {
            case .tryAgain: "Try Again"
            case .backToWorktrees: "Back to Worktrees"
            case .pairAgain: "Pair Again"
            }
        }
    }

    /// What the request came back with. Held once for the batch rather than once per file, because
    /// it is a fact about the request and the request carried five of them.
    public let failure: ApiFailure

    /// The display names of every file still blank because of it, in the order the scroll draws
    /// them. The count is what the sentence says; the first name is used only when there is one.
    public let files: [String]

    /// Whether the request is in flight again because the reader pressed.
    public let isRetrying: Bool

    /// Whether the reader has already pressed once and been refused again.
    public let hasBeenTried: Bool

    public init(failure: ApiFailure, files: [String], isRetrying: Bool, hasBeenTried: Bool) {
        self.failure = failure
        self.files = files
        self.isRetrying = isRetrying
        self.hasBeenTried = hasBeenTried
    }

    /// **The design named four failures and `ApiFailure` has sixteen**, so the rest fold into the
    /// nearest of the four by the only axis this bar has: what the reader can do about it. A rate
    /// limit, a stale content hash and a request this phone could not build are all *your Mac would
    /// not answer that*, and all of them are worth pressing again.
    ///
    /// `cancelled` is in the retryable group for totality and is never reached from the model: a
    /// cancelled batch is this app tearing down its own `.task`, so no file is marked failed for it
    /// and no bar is built.
    public var remedy: Remedy {
        switch failure {
        case .unauthorized, .pairingExpired:
            .pairAgain
        case .worktreeGone:
            .backToWorktrees
        case .rateLimited, .projectNotVisible, .fileGone, .staleContentHash, .worktreeNotDeletable,
             .gitFailure, .tooLarge, .badRequest, .unsupportedApiVersion, .requestNotBuildable,
             .unreachable, .cancelled, .notUnderstood, .routeNotServed:
            .tryAgain
        }
    }

    public var headline: String {
        switch remedy {
        case .pairAgain:
            "This iPhone is no longer paired."
        case .backToWorktrees:
            "This worktree is gone."
        case .tryAgain:
            if isRetrying {
                "Trying \(subject) again…"
            } else if hasBeenTried {
                // **The second attempt drops the subject**, because by now the reader has read it
                // once and pressed a button about it. What is new is that it happened again.
                files.count == 1 ? "Still couldn’t read it." : "Still couldn’t read them."
            } else {
                "Couldn’t read \(subject)."
            }
        }
    }

    public var detail: String {
        switch remedy {
        case .pairAgain:
            "Pair again to keep reading."
        case .backToWorktrees:
            "It was removed while you were reading it."
        case .tryAgain:
            if hasBeenTried, isRetrying == false {
                // **The reason stops and the remedy starts**, which is the whole-screen failure's
                // own sentence arriving only once the obvious thing has already been tried. Saying
                // *your Mac is out of reach* a second time tells a reader who just pressed a button
                // nothing they did not already have.
                "Check that Granita is running on your Mac."
            } else if isOutOfReach {
                "Your Mac is out of reach."
            } else {
                files.count == 1 ? "Your Mac couldn’t read it." : "Your Mac couldn’t read them."
            }
        }
    }

    /// The one thing VoiceOver is told, once per batch.
    ///
    /// **It names the control rather than only the news**, because the control is chrome at the far
    /// end of the screen: a reader who cannot see it has no way to discover by scrolling that there
    /// is anything to press, and this is the one thing on the screen they could not have caused.
    public var announcement: String {
        "\(headline) \(remedy.label) is at the bottom of the screen."
    }

    /// One file names itself and several are counted.
    ///
    /// **The reader with one blank card is told which**, and from two upwards naming them all is a
    /// paragraph while naming one of them is arbitrary. Interpolated rather than formatted, because
    /// a batch is five files and the accumulated total is a handful — there is no grouping separator
    /// in this range, and a locale-dependent string in a domain type is the trap that made `+1,204`
    /// come back as `+1.204` from a simulator on a different region.
    private var subject: String {
        files.count == 1 ? (files.first ?? "1 file") : "\(files.count) files"
    }

    /// Whether the remedy is about the network rather than about the Mac's own reading.
    ///
    /// A host that will not make a URL is the Mac being unreachable as far as anyone holding the
    /// phone is concerned, and it is the one non-network failure whose remedy is the network's.
    private var isOutOfReach: Bool {
        switch failure {
        case .unreachable, .requestNotBuildable:
            true
        case .unauthorized, .pairingExpired, .rateLimited, .projectNotVisible, .worktreeGone,
             .worktreeNotDeletable, .fileGone, .staleContentHash, .gitFailure, .tooLarge,
             .badRequest, .unsupportedApiVersion, .cancelled, .notUnderstood, .routeNotServed:
            false
        }
    }
}
