import Foundation

/// The claim one process makes on the document, so two of them cannot both hold it.
///
/// SPEC §9 asks for a lock file beside the store and says the second process to start refuses.
/// **Refuses rather than opening read-only**, which Davide settled on 22 August 2026: two processes
/// disagreeing about which repositories are switched on, with a phone reading one of them and
/// nobody told which, is worse than a Mac that says it is not serving and why.
///
/// A seam because the alternative is `flock` inside a composition root, where the refusal — the one
/// branch that matters — is unreachable from any test.
public protocol StoreLocking: Sendable {

    /// Takes the lock, or says who already has it.
    ///
    /// Held for the life of the process rather than released, which is what makes the answer
    /// meaningful: a conformer that let go would be answering a question about a moment.
    func acquire() async -> StoreLockOutcome
}

public enum StoreLockOutcome: Hashable, Sendable {

    case acquired

    /// Somebody else has it, and this is who. Named rather than counted, because design §7 wants a
    /// row a reader can act on — a process identifier can be looked up, quit or killed, and
    /// "another copy of Granita is running" cannot.
    ///
    /// **`nil` when the holder could not be read, and the refusal still stands.** Whether the lock
    /// is taken is a fact the kernel answers; who has it is read out of a file beside it, and the
    /// two can disagree for a moment — a process that has just taken the lock has not yet written
    /// its name into it. A refusal that softened into an acquisition on that window would be two
    /// processes writing one document, which is the whole thing this prevents.
    case heldBy(StoreLockHolder?)
}

/// The process holding the lock, as the lock file records it.
///
/// Both fields, because neither is enough alone: a name without an identifier does not say *which*
/// `granita-server`, and an identifier without a name is a number a reader has to go and resolve
/// before it means anything.
public struct StoreLockHolder: Hashable, Sendable, Codable {

    public let processIdentifier: Int32
    public let processName: String

    public init(processIdentifier: Int32, processName: String) {
        self.processIdentifier = processIdentifier
        self.processName = processName
    }

    /// Whoever is asking — the menu bar app, or `granita-server` in a terminal.
    ///
    /// A factory rather than a default on the initialiser, which is where every default in this
    /// package lives. Both composition roots want the same answer and neither should be the place
    /// that knows how to ask `ProcessInfo` for it, while a test wants to be some other process
    /// entirely and gets that by using the memberwise initialiser instead.
    public static var thisProcess: StoreLockHolder {
        StoreLockHolder(
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            processName: ProcessInfo.processInfo.processName
        )
    }

    /// What a reader is shown, in one line, on a row that has one.
    ///
    /// Here rather than in the view because two surfaces say it — General's status and Advanced's
    /// row — and a sentence spelled twice is two sentences that drift.
    public var sentence: String {
        "\(processName) (process \(processIdentifier))"
    }
}
