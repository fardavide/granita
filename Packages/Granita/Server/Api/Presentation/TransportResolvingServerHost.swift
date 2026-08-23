import ServerApiDomain
import ServerIdentityDomain

/// The API server, with its transport resolved **once per run** rather than once per launch.
///
/// A wrapper rather than a parameter on the configuration, because the identity behind a TLS
/// transport is asked for per run. A rebind after waking has to be able to fail for a reason someone
/// can act on — a keychain that is locked, or an identity deleted by hand between one bind and the
/// next — and a transport built once at launch could only report that as the app never having
/// started.
///
/// It resolves a transport rather than an identity so that the thing being late-bound is the same
/// value `ApiServerConfiguration` already takes. That is also what makes the wrapper reachable from
/// a host test: plaintext on loopback drives every line of it, and the four sentences below are
/// asserted rather than described.
public struct TransportResolvingServerHost: ServerHosting {

    private let dependencies: ApiDependencies
    private let binding: ApiServerBinding
    private let transport: @Sendable () async throws(ServerIdentityError) -> ApiTransport

    public init(
        dependencies: ApiDependencies,
        binding: ApiServerBinding,
        transport: @escaping @Sendable () async throws(ServerIdentityError) -> ApiTransport
    ) {
        self.dependencies = dependencies
        self.binding = binding
        self.transport = transport
    }

    public func run() -> AsyncStream<ServerRunState> {
        let dependencies = dependencies
        let binding = binding
        let transport = transport
        return AsyncStream { continuation in
            let serving = Task {
                continuation.yield(.starting)
                do {
                    let host = ApiServerHost(
                        configuration: ApiServerConfiguration(
                            dependencies: dependencies,
                            binding: binding,
                            transport: try await transport()
                        )
                    )
                    for await state in host.run() {
                        continuation.yield(state)
                    }
                // In words rather than as a status code, because the person who can act on any of
                // these is standing at this Mac and is reading a menu, not a log. The wording is
                // the error's own, so the Devices tab says the same thing about the same fault.
                } catch let refused as ServerIdentityError {
                    continuation.yield(.failed(reason: refused.explanation))
                } catch {
                    continuation.yield(.failed(reason: "\(error)"))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in serving.cancel() }
        }
    }
}
