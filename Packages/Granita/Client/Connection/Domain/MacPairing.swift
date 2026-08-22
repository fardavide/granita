import CorePairingDomain

/// Joining a Mac, as the layer above it needs to see the capability.
///
/// A protocol so the model that drives a screen can be tested against one fake rather than against
/// the two collaborators underneath it — which is the difference between a test about the screen's
/// state and a second copy of the test below.
public protocol MacJoining: Sendable {

    /// Spends a pairing code and keeps the only copy of what it buys.
    func pair(with link: PairingLink, as device: PairingDevice) async -> PairingOutcome

    /// Every Mac this phone holds a token for.
    func alreadyPaired() async -> Set<ServerInstanceId>
}

/// Joining a Mac, from a scanned link to a token this phone can use.
///
/// Three steps that only make sense together — read the contract, spend the code, write the token
/// down — so they are one operation rather than three a caller has to remember the order of. It
/// lives here, over protocols this module owns, because orchestrating I/O is not something a view
/// layer should be doing: what `Presentation` holds is the outcome, not the sequence.
public struct MacPairing: MacJoining {

    private let tokens: any PairingTokenStore

    /// Builds the client for one Mac. A closure rather than a stored client, because a pinned
    /// session is per Mac: the fingerprint arrives with the link, and a session built for one Mac
    /// must be incapable of reaching another.
    private let handshake: @Sendable (PairingLink) -> any ServerPairing

    public init(
        tokens: any PairingTokenStore,
        handshake: @escaping @Sendable (PairingLink) -> any ServerPairing
    ) {
        self.tokens = tokens
        self.handshake = handshake
    }

    /// Spends a pairing code and keeps the only copy of what it buys.
    ///
    /// **The contract is checked first and the code is spent second**, in that order and never the
    /// other way round: a code is single use and lasts two minutes, so learning about skew from the
    /// first read route afterwards costs the reader a walk back to the Mac for another one.
    ///
    /// Returns rather than throws, because three of the four outcomes are not errors in any useful
    /// sense — they are what the screen shows next, and a caller that had to catch them would be
    /// deciding which of its `catch` blocks was really a success.
    public func pair(with link: PairingLink, as device: PairingDevice) async -> PairingOutcome {
        let server = handshake(link)
        do {
            let health = try await server.health()
            guard health.compatibility == .sameContract else {
                return .wrongContract(health.compatibility)
            }

            let paired = try await server.pair(with: link.code, as: device)
            do {
                try await tokens.save(paired.token, issuedBy: paired.serverInstanceId)
            } catch {
                return .tokenNotStored(error)
            }
            return .paired(paired)
        } catch {
            return .refused(error)
        }
    }

    /// Every Mac this phone holds a token for.
    ///
    /// Silent on failure by design: a Keychain that will not enumerate costs an ordering, and
    /// refusing to list the Macs that are actually on the network because of it is the worse screen.
    public func alreadyPaired() async -> Set<ServerInstanceId> {
        (try? await tokens.pairedServers()) ?? []
    }
}

/// How an attempt to join a Mac ended.
public enum PairingOutcome: Hashable, Sendable {

    case paired(PairedDevice)

    /// The two ends do not speak the same contract, and **nothing was spent** finding that out.
    case wrongContract(ApiCompatibility)

    /// The Mac said no. `pairingExpired` covers a code that never existed as well as one that ran
    /// out, deliberately, and this does not invent the distinction back.
    case refused(ApiFailure)

    /// Paired, and the token could not be written down.
    ///
    /// The worst outcome there is, and it earns a case of its own: the Mac now holds a device record
    /// for a credential this phone does not have, so every later request is `unauthorized` for a
    /// reason no screen could explain. The reader has to revoke the device on the Mac before trying
    /// again — which is different advice from every other failure here.
    case tokenNotStored(PairingTokenStoreFailure)
}
