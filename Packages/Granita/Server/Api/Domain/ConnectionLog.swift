import Foundation

/// One attempt by something on the network to reach this Mac, and what came of it.
public struct ConnectionAttempt: Identifiable, Hashable, Sendable {

    public let id: UUID
    public let at: Date

    /// Where it came from, as the server saw it. Not a name: a phone that cannot authenticate has
    /// not told us who it is, and the address is the only thing that distinguishes two of them.
    public let source: String

    public let outcome: ConnectionOutcome

    public init(id: UUID, at: Date, source: String, outcome: ConnectionOutcome) {
        self.id = id
        self.at = at
        self.source = source
        self.outcome = outcome
    }
}

public enum ConnectionOutcome: Hashable, Sendable {

    /// A request carrying a token this Mac issued, and the device it was issued to.
    case accepted(device: String)

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
