import ClientConnectionDomain
import CoreApiDomain
import CorePairingDomain

/// A Mac that answers the handshake however a test needs it to.
///
/// Both answers are configured up front rather than scripted, because the **order** is the thing
/// under test: health is read before a code is spent, and a fake that only knew what to say second
/// could not tell a passing implementation from one that spent the code first. `codesOffered` is
/// what makes that assertable rather than inferred from a side effect.
actor FakeServerPairing: ServerPairing {

    /// Every code that reached the Mac. Empty is the assertion that matters when the two ends do
    /// not speak the same contract: nothing was spent finding that out.
    private(set) var codesOffered: [String] = []

    private let answeringHealth: Result<HealthResponse, ApiFailure>
    private let answeringPairing: Result<PairedDevice, ApiFailure>

    /// The key this Mac presents. Configurable and **optional** because the two paths differ
    /// exactly here: a scanned link knew the answer before anything was sent, and six words find
    /// out by asking.
    private let presented: SpkiFingerprint?

    /// Which call, if any, this Mac answers by never answering.
    ///
    /// **It never returns and it ignores cancellation**, which is deliberate: that is what a wedged
    /// `SecItemAdd` does, and a fake that merely slept would prove only that the bound outruns a
    /// sleep it is allowed to cancel.
    private let silentOn: SilentStep?

    init(
        answeringHealth: Result<HealthResponse, ApiFailure>,
        answeringPairing: Result<PairedDevice, ApiFailure>,
        presenting presented: SpkiFingerprint?,
        silentOn: SilentStep?
    ) {
        self.answeringHealth = answeringHealth
        self.answeringPairing = answeringPairing
        self.presented = presented
        self.silentOn = silentOn
    }

    func trustedFingerprint() async -> SpkiFingerprint? {
        if silentOn == .readingTheKey { await neverAnswer() }
        return presented
    }

    func health() async throws(ApiFailure) -> HealthResponse {
        if silentOn == .readingTheContract { await neverAnswer() }
        switch answeringHealth {
        case .success(let response): return response
        case .failure(let failure): throw failure
        }
    }

    func pair(with code: String, as device: PairingDevice) async throws(ApiFailure) -> PairedDevice {
        codesOffered.append(code)
        if silentOn == .spendingTheCode { await neverAnswer() }
        switch answeringPairing {
        case .success(let paired): return paired
        case .failure(let failure): throw failure
        }
    }

    private func neverAnswer() async {
        await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
    }

    enum SilentStep: Sendable {
        case readingTheContract
        case spendingTheCode
        case readingTheKey
    }
}
