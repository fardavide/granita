import CoreBrandingDomain
import Hummingbird
import NIOTransportServices

#if canImport(Network)
import Network
#endif

/// How the server is reachable.
public enum ApiServerBinding: Sendable {

    /// Bind a fixed port and do not advertise. What `--insecure-http` and the tests use, and the
    /// only form that is reachable by typing an address.
    case hostname(String, port: Int)

    /// Bind and advertise as a Bonjour service in one operation.
    ///
    /// The system chooses the port and publishes the one it chose, which is the point: a separate
    /// `NWListener` would bind the port itself, and two objects cannot bind the same TCP port — so
    /// advertising the real port fails and advertising port 0 publishes the wrong one.
    case bonjourService(name: String)
}

public struct ApiServerConfiguration: Sendable {

    public let serverVersion: String
    public let binding: ApiServerBinding

    public init(serverVersion: String, binding: ApiServerBinding) {
        self.serverVersion = serverVersion
        self.binding = binding
    }
}

public enum ApiServer {

    /// Builds the application, on an event loop group chosen to match the binding.
    ///
    /// A Bonjour binding **requires** `NIOTSEventLoopGroup`: Hummingbird routes a network endpoint
    /// through `NIOTSListenerBootstrap`, and it fails hard rather than silently if handed a plain
    /// socket bootstrap. It is also the code path that carries TLS options, so the identity work in
    /// M3 lands here without changing the shape.
    public static func make(configuration: ApiServerConfiguration) -> some ApplicationProtocol {
        Application(
            router: GranitaRouter.build(serverVersion: configuration.serverVersion),
            configuration: ApplicationConfiguration(
                address: bindAddress(for: configuration.binding),
                serverName: Branding.productName
            ),
            eventLoopGroupProvider: .shared(NIOTSEventLoopGroup(loopCount: 1))
        )
    }

    private static func bindAddress(for binding: ApiServerBinding) -> BindAddress {
        switch binding {
        case .hostname(let host, let port):
            .hostname(host, port: port)
        case .bonjourService(let name):
            .nwEndpoint(
                .service(
                    name: name,
                    type: Branding.bonjourServiceType,
                    domain: "local",
                    interface: nil
                )
            )
        }
    }
}
