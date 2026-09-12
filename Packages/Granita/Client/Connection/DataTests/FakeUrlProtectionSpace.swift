import Foundation
import Security

// Foundation exposes serverTrust as readonly with no public initializer that accepts it.
final class FakeUrlProtectionSpace: URLProtectionSpace, @unchecked Sendable { // The immutable fixture trust is read only, preserving Foundation's Sendable invariant.

    private let trust: SecTrust?

    init(
        host: String,
        port: Int,
        trust: SecTrust?,
        authenticationMethod: String = NSURLAuthenticationMethodServerTrust
    ) {
        self.trust = trust
        super.init(host: host, port: port, protocol: "https", realm: nil,
                   authenticationMethod: authenticationMethod)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("A certificate fixture must be supplied directly")
    }

    override var serverTrust: SecTrust? { trust }
}
