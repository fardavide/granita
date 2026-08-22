import ServerMacDomain

/// An actor rather than a struct, because the one thing worth asserting about this registry is
/// that a refusal can be recovered from — which needs a fake that answers differently the second
/// time it is asked.
actor FakeLoginItemRegistry: LoginItemRegistry {

    private var isRegisteredValue: Bool
    private var failure: LoginItemFailure?

    init(isRegistered: Bool, failure: LoginItemFailure?) {
        isRegisteredValue = isRegistered
        self.failure = failure
    }

    /// Stands in for the reader going to Login Items and allowing what was blocked.
    func stopRefusing() {
        failure = nil
    }

    func isRegistered() async -> Bool {
        isRegisteredValue
    }

    func register() async throws(LoginItemFailure) {
        if let failure {
            throw failure
        }
        isRegisteredValue = true
    }

    func unregister() async throws(LoginItemFailure) {
        if let failure {
            throw failure
        }
        isRegisteredValue = false
    }
}
