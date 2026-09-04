import CoreApiDomain
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
    ///
    /// **The Mac is named separately from the credential**, because a credential does not carry a
    /// name a reader would recognise: a scanned link carries a host, six words carry neither. What
    /// the reader tapped is what titles every screen from here on, so it is passed rather than
    /// derived.
    func pair(
        with attempt: PairingAttempt,
        on mac: DiscoveredServer,
        as device: PairingDevice
    ) async -> PairingOutcome

    /// Writes down a pairing that already happened, and nothing else.
    ///
    /// Named for the token because the token is the part a reader is told about when it fails, and
    /// design §5's sentence for that failure is about a key. What is written is the whole pairing —
    /// the key alone would be a Mac this phone could authenticate to and could not pin.
    func saveToken(of pairing: PairedMac) async -> PairingOutcome

    /// Every Mac this phone can open without pairing again.
    func rememberedMacs() async -> Set<BonjourInstanceName>
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

    private let macs: any RememberedMacStore

    /// Builds the client for one attempt. A closure rather than a stored client, because a session
    /// is per Mac: the pin — or the decision to trust the first answer — arrives with the attempt,
    /// and a session built for one Mac must be incapable of reaching another.
    private let handshake: @Sendable (PairingAttempt) -> any ServerPairing

    /// How long any one step has to answer before the attempt ends as a sentence.
    ///
    /// **A backstop, never a policy, and the number says so.** Every step below this already has a
    /// deadline of its own — the transport's request timeout is a minute — so a shorter bound here
    /// would replace the transport's own diagnostic with a worse one on an ordinary bad network.
    /// What it is for is the step that has no deadline at all: the Keychain is a synchronous call
    /// into another process, nothing above it can call it off, and a wedged one used to end as a
    /// spinner with no screen behind it. See `.claude/docs/decisions.md`.
    private let patience: Duration

    public init(
        macs: any RememberedMacStore,
        handshake: @escaping @Sendable (PairingAttempt) -> any ServerPairing
    ) {
        self.init(macs: macs, handshake: handshake, patience: .seconds(75))
    }

    /// The seam, without a default on it, so a test that means "this step never answers" has to say
    /// how long the sequence waits before it says so.
    init(
        macs: any RememberedMacStore,
        handshake: @escaping @Sendable (PairingAttempt) -> any ServerPairing,
        patience: Duration
    ) {
        self.macs = macs
        self.handshake = handshake
        self.patience = patience
    }

    /// Spends a pairing code and keeps the only copy of what it buys.
    ///
    /// **The contract is checked first and the code is spent second**, in that order and never the
    /// other way round: a code is single use and lasts two minutes, so learning about skew from the
    /// first read route afterwards costs the reader a walk back to the Mac for another one.
    ///
    /// Returns rather than throws, because most of the outcomes are not errors in any useful sense —
    /// they are what the screen shows next, and a caller that had to catch them would be deciding
    /// which of its `catch` blocks was really a success.
    ///
    /// **It always returns.** Every awaited step is bounded, so there is no path out of here that is
    /// not a `PairingOutcome`; a spinner with nothing behind it is not one of the things this can do.
    public func pair(
        with attempt: PairingAttempt,
        on mac: DiscoveredServer,
        as device: PairingDevice
    ) async -> PairingOutcome {
        let server = handshake(attempt)

        // **Every step is bounded, including the ones that look instantaneous**, and the bound is
        // per step rather than over the whole sequence so that what the reader is told names the
        // moment it stopped — which is the only thing that decides whether the code was spent.
        guard let contract = await answer(from: { await server.read() }) else {
            return .neverAnswered(.readingTheContract)
        }
        let health: HealthResponse
        switch contract {
        case .success(let response): health = response
        case .failure(let failure): return .refused(failure)
        }
        guard health.compatibility == .sameContract else {
            return .wrongContract(health.compatibility)
        }

        guard let spent = await answer(from: { await server.spend(attempt.code, as: device) }) else {
            // Past this line the code has left the phone, so nothing may say it was not used.
            return .neverAnswered(.spendingTheCode)
        }
        let paired: PairedDevice
        switch spent {
        case .success(let device): paired = device
        case .failure(let failure): return .refused(failure)
        }

        // Asked rather than taken from the attempt, because on the spoken path the attempt carried
        // no pin and the answer is whatever first contact found.
        guard let observed = await answer(from: { await server.trustedFingerprint() }) else {
            return .neverAnswered(.spendingTheCode)
        }
        guard let fingerprint = observed else {
            return .refused(.notUnderstood(diagnostic: "the Mac was reached without presenting a key"))
        }
        return await saveToken(
            of: PairedMac(
                instance: mac.id,
                name: mac.name,
                device: paired,
                address: attempt.address,
                fingerprint: fingerprint,
                // From the health read above, which is the only moment this phone is guaranteed to
                // be talking to a Mac that is awake. A Mac too old to report any leaves this empty
                // and is simply never woken.
                wakeAddresses: HardwareAddress.all(in: health.wakeAddresses ?? [])
            )
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
        let macs = macs
        let written = await answer { await macs.write(pairing) }
        guard let written else {
            return .neverAnswered(.writingTheKey(pairing))
        }
        if let failure = written {
            return .tokenNotStored(pairing, failure)
        }
        return .paired(pairing)
    }

    /// Every Mac this phone can open without pairing again.
    ///
    /// Silent on failure by design, and the cost of that silence is one pairing rather than a screen
    /// nobody can leave: a Keychain that will not enumerate sends the reader through the pairing
    /// spine for a Mac they have already paired with, where refusing to list the Macs on the network
    /// at all would leave them with nothing to tap. Bounded for the same reason.
    public func rememberedMacs() async -> Set<BonjourInstanceName> {
        let macs = macs
        return await answer { try? await macs.rememberedMacs() }.flatMap { $0 } ?? []
    }

    /// Whatever the step answers, or nothing once the patience has run out.
    ///
    /// **Deliberately not a task group.** A group awaits every child before it returns, so a step
    /// that ignores cancellation would hold the group open for exactly as long as it would have held
    /// the caller — which is to say the bound would be decorative. The step that this exists for is
    /// precisely the uncancellable kind, so what is raced is a one-shot answer rather than two
    /// children of a structured parent.
    private func answer<Value: Sendable>(
        from step: @escaping @Sendable () async -> Value
    ) async -> Value? {
        let first = FirstAnswer<Value>()
        let running = Task { await first.settle(on: step()) }
        let givingUp = Task {
            try await Task.sleep(for: patience)
            await first.settle(on: nil)
        }
        defer {
            running.cancel()
            givingUp.cancel()
        }
        return await first.answer()
    }
}

// MARK: -

/// The first of two answers, and only ever the first.
///
/// It exists so that a step which never returns cannot keep the caller: the patience settles this
/// with nothing, the caller reads it, and the step is left to finish or not finish on its own.
///
/// **Internal rather than file-private, for the same reason the patience seam above it is.** Both of
/// its guarantees are about the loser of a race — a second answer that is dropped, and a first one
/// that is still readable after it arrived — and neither can be produced on demand through
/// `answer(from:)`, which is a race the harness does not get to schedule. Asserted here, they are
/// two sentences; asserted through the sequence, they are a coin flip.
actor FirstAnswer<Value: Sendable> {

    private var settled: Value??
    private var waiting: CheckedContinuation<Value?, Never>?

    func settle(on answer: Value?) {
        guard settled == nil else { return }
        settled = .some(answer)
        waiting?.resume(returning: answer)
        waiting = nil
    }

    func answer() async -> Value? {
        if let settled {
            return settled
        }
        return await withCheckedContinuation { continuation in
            waiting = continuation
        }
    }
}

// MARK: -

/// The two calls this sequence makes over the wire, as one value each rather than as a typed throw.
///
/// `answer(from:)` races a step against a clock, and a racer has to be a value: a typed `throws`
/// cannot cross that boundary without being caught and rebuilt on the other side, which would put
/// the mapping from a Mac's refusal to a screen in two places instead of one.
private extension ServerPairing {

    func read() async -> Result<HealthResponse, ApiFailure> {
        do {
            return .success(try await health())
        } catch {
            return .failure(error)
        }
    }

    func spend(_ code: String, as device: PairingDevice) async -> Result<PairedDevice, ApiFailure> {
        do {
            return .success(try await pair(with: code, as: device))
        } catch {
            return .failure(error)
        }
    }
}

/// The write, as the failure it produced rather than as a typed throw, for the same reason.
private extension RememberedMacStore {

    func write(_ pairing: PairedMac) async -> RememberedMacStoreFailure? {
        do {
            try await remember(pairing)
            return nil
        } catch {
            return error
        }
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
    case tokenNotStored(PairedMac, RememberedMacStoreFailure)

    /// A step took the call and never came back.
    ///
    /// **The ending the vocabulary could not spell, and its absence is what shipped 0.1.0's worst
    /// defect.** Every other case here is something that happened; this is the one where nothing
    /// did, so the screen kept drawing the state before it — which is a spinner — for as long as the
    /// reader was willing to look at it. See `.claude/docs/decisions.md`.
    case neverAnswered(PairingStall)
}

// MARK: -

/// Where the sequence stopped, which is the only thing that decides what the reader has to be told.
///
/// **The distinction is whether the code left the phone**, not which function it was. A stall before
/// it is sent costs nothing and is worth another tap; a stall after it means the Mac may already
/// hold a device record, and no screen may claim otherwise.
public enum PairingStall: Hashable, Sendable {

    /// The contract read never came back, so **nothing was spent** — the same sentence, and the same
    /// truth, that the two contract states carry.
    case readingTheContract

    /// The code was handed over and no answer arrived. Whether the Mac took it cannot be known from
    /// here, which is what the screen has to say rather than guess.
    case spendingTheCode

    /// The Mac answered and the Keychain did not.
    ///
    /// It carries the pairing for the same reason a refused write does: the token survives, so the
    /// screen can offer the write on its own instead of sending the reader to the other machine.
    case writingTheKey(PairedMac)
}
