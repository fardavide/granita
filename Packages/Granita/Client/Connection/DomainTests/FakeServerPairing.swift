import ClientConnectionDomain
import CoreApiDomain

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

    init(
        answeringHealth: Result<HealthResponse, ApiFailure>,
        answeringPairing: Result<PairedDevice, ApiFailure>
    ) {
        self.answeringHealth = answeringHealth
        self.answeringPairing = answeringPairing
    }

    func health() async throws(ApiFailure) -> HealthResponse {
        switch answeringHealth {
        case .success(let response): return response
        case .failure(let failure): throw failure
        }
    }

    func pair(with code: String, as device: PairingDevice) async throws(ApiFailure) -> PairedDevice {
        codesOffered.append(code)
        switch answeringPairing {
        case .success(let paired): return paired
        case .failure(let failure): throw failure
        }
    }
}
