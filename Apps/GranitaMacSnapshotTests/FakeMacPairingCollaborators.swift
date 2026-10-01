import ClientConnectionDomain
import CorePairingDomain

struct FakeMacPairingDiscovery: ServerDiscovering {
    func discover() -> AsyncStream<DiscoveryState> {
        AsyncStream { $0.yield(.found([])); $0.finish() }
    }
}

struct FakeMacPairingJoining: MacJoining {
    let answering: PairingOutcome

    func pair(with attempt: PairingAttempt, on mac: DiscoveredServer, as device: PairingDevice) async -> PairingOutcome {
        answering
    }
    func saveToken(of pairing: PairedMac) async -> PairingOutcome { answering }
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
    func address(of server: DiscoveredServer) async throws(ServerAddressResolutionFailure) -> ServerAddress {
        ServerAddress(host: "Mac-Studio.local", port: 54_321)
    }
}

struct FakeMacPairingSettings: SystemSettingsOpening {
    @MainActor
    func open(_ pane: SystemSettingsPane) {}
}
