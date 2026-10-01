import Foundation

import ClientConnectionDomain
import CorePairingDomain

struct FakeMacPairingDiscovery: ServerDiscovering {
    func discover() -> AsyncStream<DiscoveryState> {
        AsyncStream { $0.yield(.found([])); $0.finish() }
    }
}

struct FakeMacPairingJoining: MacJoining {
    let answering: PairingOutcome
    var pairingDelay: Duration = .zero
    var savingDelay: Duration = .zero

    func pair(with attempt: PairingAttempt, on mac: DiscoveredServer, as device: PairingDevice) async -> PairingOutcome {
        do { try await Task.sleep(for: pairingDelay) } catch { return .neverAnswered(.spendingTheCode) }
        return answering
    }
    func saveToken(of pairing: PairedMac) async -> PairingOutcome {
        do { try await Task.sleep(for: savingDelay) } catch { return .neverAnswered(.writingTheKey(pairing)) }
        return answering
    }
    func rememberedMacs() async -> Set<BonjourInstanceName> { [] }
}

struct FakeMacPairingCamera: CameraAuthorizing {
    var current: CameraAccess { .restricted }
    func request() async -> CameraAccess { .restricted }
}

struct FakeMacPairingScanner: CodeScanning {
    func start() -> AsyncStream<ScannedCode> { AsyncStream { $0.finish() } }
    func stop() {}
}

struct FakeMacPairingAddressResolver: ServerAddressResolving {
    var answering: Result<ServerAddress, ServerAddressResolutionFailure> = .success(
        ServerAddress(host: "Mac-Studio.local", port: 54_321)
    )

    func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        switch answering {
        case .success(let address): return address
        case .failure(let failure): throw failure
        }
    }
}

struct FakeMacPairingSettings: SystemSettingsOpening {
    @MainActor
    func open(_ pane: SystemSettingsPane) {}
}
