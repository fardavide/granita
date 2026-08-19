import ClientConnectionDomain
import CoreBrandingDomain
import Foundation
import Network

/// Finds Granita servers by browsing for the Bonjour service the Mac advertises.
///
/// Deliberately not "connect to a stored address". The Mac binds a service endpoint and the system
/// chooses its port, so a stored `host:port` is stale as soon as the Mac restarts — the instance
/// name is the stable identity and the endpoint is resolved fresh each time.
public struct BonjourServerDiscovery: ServerDiscovering {

    /// The DNS-SD error iOS reports when the user has refused local network access.
    ///
    /// It arrives as a `.waiting` state rather than a failure, which is why a browser that is
    /// silently finding nothing looks identical to one that is working. Naming it is what lets the
    /// UI offer the fix instead of an indefinite spinner.
    private static let policyDenied: DNSServiceErrorType = -65570

    public init() {}

    public func discover() -> AsyncStream<DiscoveryState> {
        AsyncStream { continuation in
            let browser = NWBrowser(
                for: .bonjour(type: Branding.bonjourServiceType, domain: nil),
                using: .tcp
            )

            browser.stateUpdateHandler = { state in
                switch state {
                case .setup:
                    break
                case .ready:
                    continuation.yield(.searching)
                case .waiting(let error):
                    if case .dns(let code) = error, code == Self.policyDenied {
                        continuation.yield(.localNetworkDenied)
                    } else {
                        continuation.yield(.failed(error.localizedDescription))
                    }
                case .failed(let error):
                    continuation.yield(.failed(error.localizedDescription))
                    continuation.finish()
                case .cancelled:
                    continuation.finish()
                @unknown default:
                    break
                }
            }

            browser.browseResultsChangedHandler = { results, _ in
                continuation.yield(.found(results.compactMap(Self.server(from:))))
            }

            continuation.onTermination = { _ in browser.cancel() }
            continuation.yield(.searching)
            browser.start(queue: .main)
        }
    }

    /// Only service endpoints carry a name, and a name is the identity — anything else is not a
    /// server we can address later.
    private static func server(from result: NWBrowser.Result) -> DiscoveredServer? {
        guard case .service(let name, _, _, _) = result.endpoint else { return nil }
        return DiscoveredServer(id: name, name: name)
    }
}
