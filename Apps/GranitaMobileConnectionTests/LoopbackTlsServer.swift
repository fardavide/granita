import Foundation
import Network
import Security
import Synchronization
import Testing

/// The CONNECT tunnel changes only the socket destination, never the URL ATS classifies.
final class LoopbackTlsServer: Sendable {

    let proxy: ProxyConfiguration

    private let tlsListener: NWListener
    private let tunnelListener: NWListener
    private let tunnelWitness: TunnelWitness

    var acceptedTunnel: Bool {
        tunnelWitness.accepted.withLock { $0 }
    }

    init(host: String) async throws {
        let witness = TunnelWitness()
        tunnelWitness = witness
        let fixture = try #require(Bundle(for: FixtureBundle.self).url(
            forResource: "identity.p12", withExtension: "base64"
        ))
        let encoded = try String(contentsOf: fixture, encoding: .utf8)
        let archive = try #require(Data(base64Encoded: encoded, options: .ignoreUnknownCharacters))
        // These are Security's legacy dictionary boundaries; no untyped values escape import.
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: "granita-test-only",
            kSecImportToMemoryOnly as String: true
        ]
        var imported: CFArray?
        let status = SecPKCS12Import(archive as CFData, options as CFDictionary, &imported)
        try #require(status == errSecSuccess)
        let items = try #require(imported as? [NSDictionary])
        let item = try #require(items.first)
        let object = try #require(item.object(forKey: kSecImportItemIdentity)) as AnyObject
        try #require(CFGetTypeID(object) == SecIdentityGetTypeID())
        // The imported array retains this immutable object; its exact CF type was checked above.
        let identity = Unmanaged<SecIdentity>.fromOpaque(
            Unmanaged.passUnretained(object).toOpaque()
        ).takeUnretainedValue()
        let nativeIdentity = try #require(sec_identity_create(identity))
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_local_identity(tls.securityProtocolOptions, nativeIdentity)
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        let tlsParameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        tlsParameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        tlsListener = try NWListener(using: tlsParameters)
        tlsListener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            Self.readHeader(connection: connection, prefix: Data()) { _ in
                let body = "pinned fixture response"
                let reply = Data((
                    "HTTP/1.1 200 OK\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n" + body
                ).utf8)
                connection.send(content: reply, isComplete: true, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
        try await Self.start(tlsListener)
        let tlsPort = try #require(tlsListener.port)
        let destination = NWEndpoint.hostPort(host: "127.0.0.1", port: tlsPort)
        let tunnelParameters = NWParameters.tcp
        tunnelParameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        tunnelListener = try NWListener(using: tunnelParameters)
        tunnelListener.newConnectionHandler = { client in
            client.start(queue: .global())
            Self.readHeader(connection: client, prefix: Data()) { header in
                guard String(decoding: header, as: UTF8.self).hasPrefix("CONNECT \(host):8737 ") else {
                    client.cancel()
                    return
                }
                witness.accepted.withLock { $0 = true }
                let upstream = NWConnection(to: destination, using: .tcp)
                upstream.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        upstream.stateUpdateHandler = nil
                        client.send(
                            content: Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8),
                            completion: .contentProcessed { error in
                                guard error == nil else {
                                    client.cancel()
                                    upstream.cancel()
                                    return
                                }
                                Self.forward(source: client, destination: upstream)
                                Self.forward(source: upstream, destination: client)
                            }
                        )
                    case .failed, .cancelled:
                        client.cancel()
                        upstream.cancel()
                    case .setup, .preparing, .waiting:
                        break
                    @unknown default:
                        client.cancel()
                        upstream.cancel()
                    }
                }
                upstream.start(queue: .global())
            }
        }
        try await Self.start(tunnelListener)
        let port = try #require(tunnelListener.port)
        var configuration = ProxyConfiguration(
            httpCONNECTProxy: .hostPort(host: "127.0.0.1", port: port), tlsOptions: nil
        )
        configuration.matchDomains = [host]
        configuration.excludedDomains = []
        configuration.allowFailover = false
        proxy = configuration
    }

    func stop() {
        tlsListener.cancel()
        tunnelListener.cancel()
    }

    private final class TunnelWitness: Sendable {
        let accepted = Mutex(false)
    }

    private static func start(_ listener: NWListener) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                case .setup, .waiting, .cancelled:
                    break
                @unknown default:
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: ListenerFailure.unsupportedState)
                }
            }
            listener.start(queue: .global())
        }
    }

    private static func readHeader(
        connection: NWConnection,
        prefix: Data,
        completed: @escaping @Sendable (Data) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { content, _, ended, error in
            guard error == nil, let content else {
                connection.cancel()
                return
            }
            let header = prefix + content
            if header.range(of: Data("\r\n\r\n".utf8)) != nil {
                completed(header)
            } else if !ended, header.count < 65_536 {
                readHeader(connection: connection, prefix: header, completed: completed)
            } else {
                connection.cancel()
            }
        }
    }

    private static func forward(source: NWConnection, destination: NWConnection) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { content, _, ended, error in
            guard error == nil else {
                source.cancel()
                destination.cancel()
                return
            }
            destination.send(content: content, isComplete: ended, completion: .contentProcessed { error in
                if ended || error != nil {
                    source.cancel()
                    destination.cancel()
                } else {
                    forward(source: source, destination: destination)
                }
            })
        }
    }

    private enum ListenerFailure: Error {
        case unsupportedState
    }
}

private final class FixtureBundle: NSObject {}
