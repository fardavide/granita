import ClientConnectionDomain

/// The Keychain, in memory.
///
/// An actor because the protocol is asynchronous and the real one is reached from anywhere; the
/// saved tokens are exposed so a test can assert that the only copy of a credential was in fact
/// written down.
actor FakePairingTokenStore: PairingTokenStore {

    private(set) var saved: [ServerInstanceId: PairingToken]

    private let refusal: PairingTokenStoreFailure?

    init(holding saved: [ServerInstanceId: PairingToken] = [:]) {
        self.saved = saved
        refusal = nil
    }

    /// A Keychain that will not cooperate, which is the one failure that leaves a phone paired with
    /// a Mac and holding nothing.
    init(refusing refusal: PairingTokenStoreFailure) {
        saved = [:]
        self.refusal = refusal
    }

    func token(issuedBy server: ServerInstanceId) async throws(PairingTokenStoreFailure) -> PairingToken? {
        if let refusal { throw refusal }
        return saved[server]
    }

    func save(_ token: PairingToken, issuedBy server: ServerInstanceId) async throws(PairingTokenStoreFailure) {
        if let refusal { throw refusal }
        saved[server] = token
    }

    func remove(issuedBy server: ServerInstanceId) async throws(PairingTokenStoreFailure) {
        if let refusal { throw refusal }
        saved[server] = nil
    }

    func pairedServers() async throws(PairingTokenStoreFailure) -> Set<ServerInstanceId> {
        if let refusal { throw refusal }
        return Set(saved.keys)
    }
}
