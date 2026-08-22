import Foundation

/// One attempt by something on the network to reach this Mac, and what came of it.
public struct ConnectionAttempt: Identifiable, Hashable, Sendable {

    /// SPEC §9's fifty, as many as the panel ever holds. A phone retrying every second fills that in
    /// under a minute, and what is wanted then is the last minute rather than the first.
    ///
    /// Here rather than on the log that enforces it, because the panel's footer says the number out
    /// loud — *the last 50 attempts* — and the view cannot see the implementation. Two copies of it
    /// is a footer that goes on claiming fifty after the log has been changed to hold something else.
    public static let logCapacity = 50

    public let id: UUID
    public let at: Date

    /// Where it came from, as the server saw it. Not a name: a phone that cannot authenticate has
    /// not told us who it is, and the address is the only thing that distinguishes two of them.
    public let source: String

    public let outcome: ConnectionOutcome

    /// How many times this exact thing has happened in a row, from this source.
    ///
    /// One where nothing has repeated. The log coalesces a run of identical outcomes into a single
    /// row so that one polling phone cannot bury the row explaining another, and without this number
    /// that is also how four hundred attempts come to look like one. A phone that tried once and a
    /// phone that has been hammering this Mac for ten minutes are different problems, and the panel
    /// is the only place they are told apart.
    public let occurrences: Int

    public init(id: UUID, at: Date, source: String, outcome: ConnectionOutcome, occurrences: Int) {
        self.id = id
        self.at = at
        self.source = source
        self.outcome = outcome
        self.occurrences = occurrences
    }
}

public enum ConnectionOutcome: Hashable, Sendable {

    /// A request carrying a token this Mac issued, and the device it was issued to.
    case accepted(device: String)

    /// A device that has just paired. Distinct from being served, because it is the row someone
    /// looks for when a phone has been set up and then cannot read anything: it says the pairing
    /// itself worked and moves the question to the token.
    case paired(device: String)

    case refused(ConnectionRefusal)
}

/// Why a request was turned away.
///
/// Each case is a different thing to do about it, which is the whole reason the panel exists: "it
/// cannot connect" is not actionable and "that phone's token is not one this Mac issued" is.
public enum ConnectionRefusal: Hashable, Sendable {

    /// No `Authorization` header at all — an unpaired phone, or one whose token was revoked and
    /// which has forgotten it.
    case noToken

    /// A token that is not one of this Mac's. The common cause is pairing with a different Mac, or
    /// this Mac's store having been reset.
    case unknownToken

    case rateLimited

    /// A pairing code this Mac never issued — mistyped, meant for another Mac, or already spent.
    ///
    /// Told apart from an expired one here and nowhere else. The wire answers both the same way,
    /// because a caller that has not proved who it is must not learn which; the person reading this
    /// panel has, and the two mean different things to them — "type it again" against "be quicker".
    case pairingCodeUnknown

    /// A pairing code this Mac did issue, offered after its two minutes were up.
    case pairingCodeExpired

    /// The code was right and the device could not be written down. Nothing the phone did, and
    /// nothing it can do: the disk is full, or the data folder is not writable.
    case pairingNotRecordable(reason: String)

    /// A phone shipping ahead of this Mac. The Mac app and the phone app ship independently, so
    /// this is guaranteed rather than possible.
    case unsupportedApiVersion(sent: Int)
}

/// The last several connection attempts, for the Advanced panel.
///
/// SPEC §9 calls that panel "not optional": it is what makes a phone that will not connect
/// debuggable by someone who cannot attach a debugger. Held in memory only — it describes this run
/// of the server, and a log that survives a restart would mostly describe a Mac that has since
/// changed address.
public protocol ConnectionLog: Sendable {

    func record(source: String, outcome: ConnectionOutcome) async

    /// Every reading of the log, newest attempt first, beginning with what it holds now.
    ///
    /// A stream rather than an accessor because the panel is watched *while* a phone is failing to
    /// connect: the attempt worth seeing is the one that has not happened yet when it is opened.
    func attempts() async -> AsyncStream<[ConnectionAttempt]>
}
