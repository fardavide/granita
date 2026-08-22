/// Where the phone keeps the one copy of a pairing token.
///
/// Not a cache. The Mac stores only a hash, so a token that is lost here cannot be recovered from
/// there and the reader has to pair again — which is why the implementation is the Keychain rather
/// than a preference, and why every failure to write one has to be reported rather than shrugged at.
///
/// Keyed by which Mac issued it. A phone may be paired with more than one, and the identifier is
/// stable across a Mac's restarts and its renames where a host and port are not.
public protocol PairingTokenStore: Sendable {

    /// The token for that Mac, or nothing if this phone has never paired with it.
    func token(issuedBy server: ServerInstanceId) async throws(PairingTokenStoreFailure) -> PairingToken?

    /// Writes a token, replacing whatever was there. Re-pairing with a Mac is an ordinary thing to
    /// do and must not fail because a previous token exists.
    func save(_ token: PairingToken, issuedBy server: ServerInstanceId) async throws(PairingTokenStoreFailure)

    /// Forgets a Mac. Removing something that is not there is not a failure.
    func remove(issuedBy server: ServerInstanceId) async throws(PairingTokenStoreFailure)

    /// Every Mac this phone holds a token for, without reading any of the tokens.
    ///
    /// What the discovery list's two sections are built from — a Mac paired with before belongs
    /// above one that has never been seen. The identifiers only, because nothing that merely wants
    /// to sort a list should be handling credentials.
    func pairedServers() async throws(PairingTokenStoreFailure) -> Set<ServerInstanceId>
}

public enum PairingTokenStoreFailure: Error, Hashable, Sendable {

    /// The Keychain said no, with its own status code — the only part of a Keychain failure anyone
    /// can act on, and the reader of this app is the person who can act on it.
    case refused(status: Int32)

    /// Something is stored under that key and it is not a token.
    case unreadable
}
