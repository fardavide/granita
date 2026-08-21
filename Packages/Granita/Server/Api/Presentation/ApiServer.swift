import Foundation
import Hummingbird
import NIOCore
import NIOTransportServices

import CoreBrandingDomain
import ServerApiDomain

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

    public let dependencies: ApiDependencies
    public let binding: ApiServerBinding

    public init(dependencies: ApiDependencies, binding: ApiServerBinding) {
        self.dependencies = dependencies
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
    /// - Parameter onRunning: Called once the listener is up, with the address it ended up on.
    ///   `nil` when the channel cannot say, which the caller has to treat as a state rather than
    ///   paper over: with a Bonjour bind the port is the system's choice, so it is not knowable
    ///   from the configuration.
    public static func make(
        configuration: ApiServerConfiguration,
        onRunning: @escaping @Sendable (ServerEndpoint?) async -> Void
    ) -> some ApplicationProtocol {
        Application(
            router: GranitaRouter.build(configuration.dependencies),
            configuration: ApplicationConfiguration(
                address: bindAddress(for: configuration.binding),
                serverName: Branding.productName
            ),
            onServerRunning: { channel in
                await onRunning(endpoint(of: channel, for: configuration.binding))
            },

            eventLoopGroupProvider: .shared(NIOTSEventLoopGroup(loopCount: 1))
        )
    }

    private static func endpoint(of channel: any Channel, for binding: ApiServerBinding) async -> ServerEndpoint? {
        guard let port = await boundPort(of: channel) else { return nil }
        switch binding {
        case .hostname(let host, _):
            return ServerEndpoint(host: host, port: port)
        case .bonjourService:
            // The service name is what the phone browses for; what belongs on a status line beside
            // a port is the name that resolves to this Mac.
            return ServerEndpoint(host: MachineName.localHost, port: port)
        }
    }

    /// **TRAP.** A channel bound to a network endpoint has **no** `localAddress`: there is no POSIX
    /// socket under it, so the obvious reading comes back `nil` and a status line built from it
    /// says the server is up but nowhere. The port lives on the `NWListener` the system bound —
    /// which is the same object that chose it, since a Bonjour service endpoint hands that choice
    /// to the system.
    ///
    /// Read on the event loop and reduced to a number there, so nothing from Network crosses back.
    private static func boundPort(of channel: any Channel) async -> Int? {
        let listened = try? await channel
            .getOption(NIOTSChannelOptions.listener)
            .map { listener in listener?.port?.rawValue }
            .get()
        if let port = listened ?? nil {
            return Int(port)
        }
        return channel.localAddress?.port
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
