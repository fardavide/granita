import CorePairingDomain

/// Where a Mac is, right now.
///
/// Not stored anywhere and not an identity: a Granita binds a service endpoint and the system
/// chooses the port, so this goes stale the moment the Mac restarts. It exists because the two
/// credentials arrive with it differently — a scanned link carries one, and six words have to have
/// one resolved for them.
public struct ServerAddress: Hashable, Sendable {

    /// A name this Mac answers to, never a path. The rule the whole API rests on applies here too.
    public let host: String

    public let port: Int

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
}

/// The two ways a reader offers a pairing, and the one place their difference is written down.
///
/// **They redeem the same pairing and they do not buy the same guarantee.** The QR carries the
/// fingerprint over a channel nobody on the network can write to — the Mac's own screen — so the
/// scanned path knows what it is talking to before it sends a byte. Six words carry a code and
/// nothing else, and the address they borrow comes from a Bonjour record any device on the LAN can
/// publish, so that path trusts whoever answers first.
///
/// Modelled as one type with an optional pin rather than as two parallel flows, because every step
/// after this one — read the contract, spend the code, write the token down — is identical, and two
/// flows would be two places for that sequence to drift. The asymmetry is a single property, and
/// `nil` is the whole of it. See `.claude/docs/decisions.md`.
public enum PairingAttempt: Hashable, Sendable {

    /// Read off the Mac's screen, fingerprint included.
    case scanned(PairingLink)

    /// Typed, against a Mac the browse found. **Trust on first use**, and the screen that offers it
    /// says so in as many words.
    case spoken(code: String, at: ServerAddress)

    public var code: String {
        switch self {
        case .scanned(let link): link.code
        case .spoken(let code, _): code
        }
    }

    public var address: ServerAddress {
        switch self {
        case .scanned(let link): ServerAddress(host: link.host, port: link.port)
        case .spoken(_, let address): address
        }
    }

    /// The key to pin, when one is known in advance. `nil` is trust on first use, and it is the
    /// only difference between the two cases.
    public var pin: SpkiFingerprint? {
        switch self {
        case .scanned(let link): link.fingerprint
        case .spoken: nil
        }
    }
}

/// A Mac this phone is now paired with, and everything needed to read from it and to name it.
///
/// The three technical facts have to travel together: the token authenticates, the address says
/// where, and the fingerprint is what makes a session refuse to reach anywhere else. Splitting them
/// would let a caller build a session for one Mac with another one's pin, which is the mistake the
/// pinned transport exists to make impossible.
///
/// **The name travels with them for a reason of the same kind.** Design §5 titles the worktree list
/// with the Mac's name, and nothing else in this value is that name: the address is a host and a
/// port, and a Mac reached over `192.168.1.24` would put an IP address at the top of the one screen
/// this product exists for. Deriving it there would also be a second answer to a question the Mac
/// list already answered.
public struct PairedMac: Hashable, Sendable {

    /// Which Mac this is, on this network, and **what the pairing is filed under so that the next
    /// tap does not have to ask for a code again.** It is carried rather than derived from the name
    /// beside it: the two are the same string in every browse result today, and a display name that
    /// stopped being an identity would quietly re-file every remembered Mac.
    public let instance: BonjourInstanceName

    /// What the reader calls this Mac, which is the string they tapped in the Mac list and saw at
    /// the top of every pairing screen after it. The Bonjour instance's own display name.
    public let name: String

    public let device: PairedDevice

    public let address: ServerAddress

    /// **What was actually trusted**, which is not always what was asked for. On the scanned path
    /// it is the link's pin; on the spoken path it is the key first contact found, read back from
    /// the handshake rather than assumed — nothing above that seam may invent a fingerprint it did
    /// not observe.
    public let fingerprint: SpkiFingerprint

    public init(
        instance: BonjourInstanceName,
        name: String,
        device: PairedDevice,
        address: ServerAddress,
        fingerprint: SpkiFingerprint
    ) {
        self.instance = instance
        self.name = name
        self.device = device
        self.address = address
        self.fingerprint = fingerprint
    }
}
