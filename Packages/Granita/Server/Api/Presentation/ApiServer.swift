import Foundation
import Hummingbird
import NIOCore
import NIOTransportServices
import Security

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

/// What the bytes on the wire are wrapped in.
///
/// An enumeration rather than an optional identity, so that plaintext is a thing the code says out
/// loud wherever it is chosen — including in the line the terminal prints when it starts.
public enum ApiTransport: @unchecked Sendable {

    /// TLS under the identity this Mac generated at first run and keeps in the login Keychain.
    ///
    /// `SecIdentity` is a Core Foundation object: immutable once created and safe to use from any
    /// thread, which is not something the compiler can see. Nothing here mutates it.
    case tls(SecIdentity)

    /// Plain HTTP. `granita-server --insecure-http` only — off by default, never reachable from
    /// the Mac app's UI, and it exists so that a TLS problem can never leave code unreviewable.
    case insecurePlaintext
}

public struct ApiServerConfiguration: Sendable {

    public let dependencies: ApiDependencies
    public let binding: ApiServerBinding
    public let transport: ApiTransport

    public init(dependencies: ApiDependencies, binding: ApiServerBinding, transport: ApiTransport) {
        self.dependencies = dependencies
        self.binding = binding
        self.transport = transport
    }
}

public enum ApiServerError: Error, Hashable, Sendable {

    /// The Keychain identity could not be turned into TLS options.
    ///
    /// Fatal on purpose. The tempting alternative — fall back to plaintext and carry on — would
    /// serve private source code in the clear to a phone that believes it is on TLS, and the only
    /// symptom would be that everything works.
    case tlsIdentityRefused
}

public enum ApiServer {

    /// Builds the application, on an event loop group chosen to match the binding.
    ///
    /// A Bonjour binding **requires** `NIOTSEventLoopGroup`: Hummingbird routes a network endpoint
    /// through `NIOTSListenerBootstrap`, and it fails hard rather than silently if handed a plain
    /// socket bootstrap.
    ///
    /// **Listening, advertising and TLS are one operation here, not three.** That same bootstrap is
    /// what carries `tlsOptions`, which is why the identity goes into the configuration below
    /// rather than into a second object wrapped around this one — and why the trap SPEC §8 records
    /// about a separate `NWListener` stays solved rather than being re-opened by the TLS work.
    ///
    /// - Parameter onRunning: Called once the listener is up, with the address it ended up on.
    ///   `nil` when the channel cannot say, which the caller has to treat as a state rather than
    ///   paper over: with a Bonjour bind the port is the system's choice, so it is not knowable
    ///   from the configuration.
    public static func make(
        configuration: ApiServerConfiguration,
        onRunning: @escaping @Sendable (ServerEndpoint?) async -> Void
    ) throws(ApiServerError) -> some ApplicationProtocol {
        Application(
            router: GranitaRouter.build(configuration.dependencies),
            configuration: ApplicationConfiguration(
                address: bindAddress(for: configuration.binding),
                serverName: Branding.productName,
                tlsOptions: try tlsOptions(for: configuration.transport)
            ),
            onServerRunning: { channel in
                await onRunning(endpoint(of: channel, for: configuration.binding))
            },

            eventLoopGroupProvider: .shared(NIOTSEventLoopGroup(loopCount: 1))
        )
    }

    private static func tlsOptions(for transport: ApiTransport) throws(ApiServerError) -> TSTLSOptions {
        switch transport {
        case .tls(let identity):
            // Refused rather than downgraded. `TSTLSOptions` reports this by handing back nothing,
            // and `?? .none` would be a server that quietly serves plaintext on the port it
            // advertised as TLS.
            guard let options = TSTLSOptions.options(serverIdentity: .secIdentity(identity)) else {
                throw .tlsIdentityRefused
            }
            return options
        case .insecurePlaintext:
            return .none
        }
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
