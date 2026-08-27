import ClientConnectionDomain

/// The Keychain, in memory.
///
/// An actor because the protocol is asynchronous and the real one is reached from anywhere; the
/// saved pairings are exposed so a test can assert that the only copy of a credential was in fact
/// written down.
actor FakeRememberedMacStore: RememberedMacStore {

    private(set) var saved: [BonjourInstanceName: RememberedMac]

    private var refusal: RememberedMacStoreFailure?

    /// Whether every call never answers at all.
    ///
    /// **It ignores cancellation**, because that is the shape of the failure it stands in for: the
    /// Keychain is a synchronous call into another process, and nothing above it can call it off.
    /// A fake that merely slept would prove only that the bound outruns a sleep it may cancel.
    private let isSilent: Bool

    init(holding saved: [BonjourInstanceName: RememberedMac] = [:]) {
        self.saved = saved
        refusal = nil
        isSilent = false
    }

    /// A Keychain that takes the call and never comes back, which is the failure no screen existed
    /// for: every other one produces an outcome, and this one produced a spinner.
    init(neverAnswering: Void) {
        saved = [:]
        refusal = nil
        isSilent = true
    }

    /// A Keychain that will not cooperate, which is the one failure that leaves a phone paired with
    /// a Mac and holding nothing.
    init(refusing refusal: RememberedMacStoreFailure) {
        saved = [:]
        self.refusal = refusal
        isSilent = false
    }

    /// Stops refusing, so a retry can be told from a first attempt.
    ///
    /// `errSecInteractionNotAllowed` is transient, and a fake that could only ever refuse could not
    /// express the case the retry exists for — it would assert that trying again changes nothing.
    func recover() {
        refusal = nil
    }

    func remembered(
        _ mac: BonjourInstanceName
    ) async throws(RememberedMacStoreFailure) -> RememberedMac? {
        if isSilent { await neverAnswer() }
        if let refusal { throw refusal }
        return saved[mac]
    }

    func remember(_ mac: PairedMac) async throws(RememberedMacStoreFailure) {
        if isSilent { await neverAnswer() }
        if let refusal { throw refusal }
        saved[mac.instance] = RememberedMac(device: mac.device, fingerprint: mac.fingerprint)
    }

    func forget(_ mac: BonjourInstanceName) async throws(RememberedMacStoreFailure) {
        if isSilent { await neverAnswer() }
        if let refusal { throw refusal }
        saved[mac] = nil
    }

    func rememberedMacs() async throws(RememberedMacStoreFailure) -> Set<BonjourInstanceName> {
        if isSilent { await neverAnswer() }
        if let refusal { throw refusal }
        return Set(saved.keys)
    }

    private func neverAnswer() async {
        await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
    }
}
