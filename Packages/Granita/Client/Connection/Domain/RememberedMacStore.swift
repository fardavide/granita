import CorePairingDomain

/// Everything about a Mac that has to survive the app being closed, and nothing that does not.
///
/// **The address is deliberately absent.** A Granita binds a service endpoint and the system chooses
/// the port, so a stored `host:port` is wrong the first time the Mac restarts — and a phone that
/// dialled it would report the Mac as unreachable while it sat two feet away. What is stored is the
/// part that does not move; where the Mac is, is asked of Bonjour every time.
///
/// **The fingerprint is stored beside the token because they have to travel together.** A token
/// without a pin would have to be spent on whoever answered, which is precisely the trust the
/// pairing bought and would be given back on every reconnection.
public struct RememberedMac: Hashable, Sendable {

    public let device: PairedDevice

    /// The key this Mac presented when it was paired with, which is what a session built from this
    /// refuses to reach anywhere else without.
    public let fingerprint: SpkiFingerprint

    public init(device: PairedDevice, fingerprint: SpkiFingerprint) {
        self.device = device
        self.fingerprint = fingerprint
    }
}

// MARK: -

/// Where the phone keeps the one copy of everything a Mac gave it.
///
/// Not a cache. The Mac stores only a hash of the token, so a pairing that is lost here cannot be
/// recovered from there and the reader has to pair again — which is why the implementation is the
/// Keychain rather than a preference, and why every failure to write one has to be reported rather
/// than shrugged at.
///
/// **Keyed by the Bonjour instance name**, because that is the only name for a Mac the phone holds
/// at the moment it has to decide whether it already knows one. The identifier the Mac issues
/// arrives inside a pairing response, which is to say after the decision has been made.
public protocol RememberedMacStore: Sendable {

    /// What that Mac gave this phone, or nothing if the two have never paired.
    func remembered(_ mac: BonjourInstanceName) async throws(RememberedMacStoreFailure) -> RememberedMac?

    /// Writes a pairing down, replacing whatever was there. Re-pairing with a Mac is an ordinary
    /// thing to do and must not fail because a previous pairing exists.
    func remember(_ mac: PairedMac) async throws(RememberedMacStoreFailure)

    /// Forgets a Mac. Removing something that is not there is not a failure.
    ///
    /// **What a revoked token ends in.** The Mac is the only side that can withdraw a pairing, and
    /// it says so by refusing a request; forgetting is how the phone stops opening a worktree list
    /// that can only fail and offers the pairing screens again instead.
    func forget(_ mac: BonjourInstanceName) async throws(RememberedMacStoreFailure)

    /// Every Mac this phone can open without pairing, without reading any of their credentials.
    ///
    /// What the discovery list decides a tap with — a Mac paired with before goes straight to its
    /// worktrees. The names only, because nothing that merely wants to route a tap should be
    /// handling tokens.
    func rememberedMacs() async throws(RememberedMacStoreFailure) -> Set<BonjourInstanceName>
}

public enum RememberedMacStoreFailure: Error, Hashable, Sendable {

    /// The Keychain said no, with its own status code — the only part of a Keychain failure anyone
    /// can act on, and the reader of this app is the person who can act on it.
    case refused(status: Int32)

    /// Something is stored under that key and it is not a pairing.
    case unreadable
}
