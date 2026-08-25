import CorePairingDomain

/// Joining a Mac, as the layer above it needs to see the capability.
///
/// Three members rather than one because design §5's outcome screen can act on two of them
/// separately: a code is spent once, and the Keychain write it bought can be retried on its own
/// afterwards.
///
/// **It exists because a screen drives the whole sequence now.** The model that drives those four
/// screens is tested against one double for the sequence rather than against the two collaborators
/// underneath it — which is the difference between a test about what a screen shows and a second
/// copy of `MacPairingTests` one layer up. See `.claude/docs/decisions.md`.
public protocol MacJoining: Sendable {

    /// Spends a pairing code and keeps the only copy of what it buys.
    func pair(with attempt: PairingAttempt, as device: PairingDevice) async -> PairingOutcome

    /// Writes down a token for a pairing that already happened, and nothing else.
    func saveToken(of pairing: PairedMac) async -> PairingOutcome

    /// Every Mac this phone holds a token for.
    func alreadyPaired() async -> Set<ServerInstanceId>
}

// MARK: -

/// Joining a Mac, from an offered credential to a token this phone can use.
///
/// Three steps that only make sense together — read the contract, spend the code, write the token
/// down — so they are one operation rather than three a caller has to remember the order of. It
/// lives here, over protocols this module owns, because orchestrating I/O is not something a view
/// layer should be doing: what `Presentation` holds is the outcome, not the sequence.
///
/// **One sequence for both credentials.** A scanned link and six words differ in exactly one place,
/// which is whether a pin was known before anything was sent, and `PairingAttempt` is where that
/// lives. Everything here is the same either way, which is why there is one of these rather than
/// two.
public struct MacPairing: MacJoining {

    private let tokens: any PairingTokenStore

    /// Builds the client for one attempt. A closure rather than a stored client, because a session
    /// is per Mac: the pin — or the decision to trust the first answer — arrives with the attempt,
    /// and a session built for one Mac must be incapable of reaching another.
    private let handshake: @Sendable (PairingAttempt) -> any ServerPairing

    public init(
        tokens: any PairingTokenStore,
        handshake: @escaping @Sendable (PairingAttempt) -> any ServerPairing
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
    public func pair(with attempt: PairingAttempt, as device: PairingDevice) async -> PairingOutcome {
        let server = handshake(attempt)
        let paired: PairedDevice
        do {
            let health = try await server.health()
            guard health.compatibility == .sameContract else {
                return .wrongContract(health.compatibility)
            }
            paired = try await server.pair(with: attempt.code, as: device)
        } catch {
            return .refused(error)
        }

        // Asked rather than taken from the attempt, because on the spoken path the attempt carried
        // no pin and the answer is whatever first contact found.
        guard let fingerprint = await server.trustedFingerprint() else {
            return .refused(.notUnderstood(diagnostic: "the Mac was reached without presenting a key"))
        }
        return await saveToken(
            of: PairedMac(device: paired, address: attempt.address, fingerprint: fingerprint)
        )
    }

    /// Writes down a token for a pairing that already happened, and nothing else.
    ///
    /// **This is what makes a failed Keychain write recoverable.** The code that bought this token
    /// is spent, so retrying the whole sequence would be asking a Mac to honour a credential that no
    /// longer exists; what can be retried is the one step that failed. `errSecInteractionNotAllowed`
    /// — the common cause — is transient, and without this the reader's only remedy is to go to the
    /// other machine and revoke a device record.
    public func saveToken(of pairing: PairedMac) async -> PairingOutcome {
        do {
            try await tokens.save(pairing.device.token, issuedBy: pairing.device.serverInstanceId)
        } catch {
            return .tokenNotStored(pairing, error)
        }
        return .paired(pairing)
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

    case paired(PairedMac)

    /// The two ends do not speak the same contract, and **nothing was spent** finding that out.
    case wrongContract(ApiCompatibility)

    /// The Mac said no. `pairingExpired` covers a code that never existed as well as one that ran
    /// out, deliberately, and this does not invent the distinction back.
    case refused(ApiFailure)

    /// Paired, and the token could not be written down.
    ///
    /// The worst outcome there is, and it earns a case of its own: the Mac now holds a device record
    /// for a credential this phone does not have, so every later request is `unauthorized` for a
    /// reason no screen could explain.
    ///
    /// **It carries the pairing rather than only the failure**, which is what lets the screen offer
    /// a retry of the write alone instead of sending the reader to the Mac to revoke a device. The
    /// cost is stated where it belongs, in `decisions.md`: a live token sits in memory for as long as
    /// that screen is up.
    case tokenNotStored(PairedMac, PairingTokenStoreFailure)
}
