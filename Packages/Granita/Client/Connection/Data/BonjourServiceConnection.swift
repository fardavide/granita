import Dispatch
import Foundation
import Network

import ClientConnectionDomain
import CoreBrandingDomain

/// A real `NWConnection`, opened only to find out where it lands.
///
/// **Connecting is the resolution.** Network.framework offers no "resolve this service" call: the
/// way to turn a Bonjour instance name into a host and a port is to dial the service endpoint and
/// read the address off the path once it is up. Nothing is ever sent over it — the pairing handshake
/// is a separate, pinned session — so this is opened, read and stopped.
final class BonjourServiceConnection: ServiceConnecting {

    /// Connecting has no reason to be on the main queue: what the answer reaches is a main-actor
    /// view model, and the hop happens at its `await` rather than here. Off the main queue it also
    /// arrives in a host test, whose main thread belongs to the test runner.
    private static let queue = DispatchQueue(label: "granita.discovery.resolver")

    private static let policyDenied: DNSServiceErrorType = -65570

    private let connection: NWConnection

    /// A browse result carries an instance name and no domain, so `local.` is supplied here. It is
    /// the only domain this app has ever been in: SPEC §0 locks v1 to the LAN, and the Mac
    /// advertises nowhere else.
    init(to server: DiscoveredServer) {
        connection = NWConnection(
            to: .service(
                name: server.id.rawValue,
                type: Branding.bonjourServiceType,
                domain: "local.",
                interface: nil
            ),
            using: .tcp
        )
    }

    /// What a connection's state, and the path it has at that moment, ask of the stream.
    ///
    /// Separated from the callback it is read in because that one runs only against a real network,
    /// and it takes the endpoint rather than fetching it so that the whole decision is one function
    /// a host test can call. What is left in the callback is one line, which is the point of the
    /// arrangement: everything a Mac's answer is turned into is decided here.
    ///
    /// **Waiting is terminal, which is the opposite of how the browse reads it**, and deliberately.
    /// A waiting browser is alive and recovers on its own, so replacing it would be churn; a waiting
    /// connection has been told there is nothing at that name yet, and the reader is watching a
    /// spinner rather than a list. It is also how a refused local network permission arrives, which
    /// is the one diagnosis that must not be left to a timeout.
    static func change(for state: NWConnection.State, at endpoint: NWEndpoint?) -> ConnectionStateChange {
        switch state {
        case .setup, .preparing:
            .nothingYet
        case .ready:
            .last(resolution(of: endpoint))
        case .waiting(let error), .failed(let error):
            .last(.lost(failure(for: error)))
        case .cancelled:
            .nothingMore
        @unknown default:
            .nothingYet
        }
    }

    func start() -> AsyncStream<EndpointResolution> {
        AsyncStream { continuation in
            connection.stateUpdateHandler = { [connection] state in
                Self.change(for: state, at: connection.currentPath?.remoteEndpoint).apply(to: continuation)
            }
            connection.start(queue: Self.queue)
        }
    }

    func cancel() {
        connection.cancel()
    }

    /// What a connected path amounts to.
    ///
    /// A host and a port is the whole answer, and anything else is a connection that came up without
    /// saying where — the unresolved service endpoint it was opened to, or no path at all, both of
    /// which the framework permits and neither of which can be dialled. The host is whatever the
    /// system reached, literal address included: the Mac's certificate is judged by its key rather
    /// than by the name it was reached under, so there is nothing here that a name would buy.
    private static func resolution(of endpoint: NWEndpoint?) -> EndpointResolution {
        guard let endpoint, case .hostPort(let host, let port) = endpoint else {
            return .lost(.unreachable(diagnostic: "the connection came up without an address on its path"))
        }
        return .reached(ServerAddress(host: "\(host)", port: Int(port.rawValue)))
    }

    /// The one code that means the app may not speak to the LAN at all, and everything else.
    ///
    /// Read through the `NSError` bridge rather than by switching on the kind, for the reason the
    /// browse's restart policy already records: `NWError` is not frozen, so a switch would need a
    /// branch no test can reach, and the bridge carries the underlying code for every kind there is
    /// including one that does not exist yet.
    private static func failure(for error: NWError) -> ServerAddressResolutionFailure {
        if case .dns(let code) = error, code == policyDenied {
            return .localNetworkDenied
        }
        return .unreachable(diagnostic: "\(error.localizedDescription)\nNWError \((error as NSError).code)")
    }
}

// MARK: -

/// What a connection's state change asks of the stream carrying its answer.
///
/// It carries the answer rather than an instruction to go and fetch one, and that is what keeps the
/// state callback to a single line — the whole of what only a real network runs.
enum ConnectionStateChange: Equatable {

    /// Still connecting. Nothing to say, and more will arrive.
    case nothingYet

    /// The last thing this connection will say, whether that is where the Mac is or why it cannot
    /// be said. Both end the stream, because a connection that has answered has nothing left to add
    /// and one that has failed will never answer.
    case last(EndpointResolution)

    /// Finished with nothing to add: a cancelled connection was stopped on purpose.
    case nothingMore

    func apply(to continuation: AsyncStream<EndpointResolution>.Continuation) {
        switch self {
        case .nothingYet:
            break
        case .last(let resolution):
            continuation.yield(resolution)
            continuation.finish()
        case .nothingMore:
            continuation.finish()
        }
    }
}
