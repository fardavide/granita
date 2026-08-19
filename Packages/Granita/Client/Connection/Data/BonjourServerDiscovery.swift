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

    /// A refused local network permission, reported while the browser waits.
    ///
    /// This is what the *first* browser an app creates reports, and it arrives as `.waiting` rather
    /// than a failure — which is why a browser that is silently finding nothing looks identical to
    /// one that is working.
    private static let policyDenied: DNSServiceErrorType = -65570

    /// The same refusal, seen by a browser created *after* one was already refused.
    ///
    /// A reopened app cannot reach mDNSResponder at all and fails outright rather than waiting.
    /// Found on device: granting and then revoking permission produced a correct refusal screen on
    /// the first run and a raw `NWError -65569` on the next, because only `policyDenied` was known.
    ///
    /// The attribution is a judgement rather than a certainty — this code can in principle mean the
    /// daemon connection died for another reason. It is worth making anyway: the cost of being
    /// wrong is a Settings button that does not help, against a cost of being right that is the
    /// reader stuck at an error string with no idea the permission is the problem.
    private static let defunctConnection: DNSServiceErrorType = -65569

    public init() {}

    /// Maps a browser error to what the reader should be told.
    ///
    /// Separated from the browser so it can be tested against constructed errors — the two refusal
    /// codes are otherwise reachable only by revoking a permission on a physical device.
    static func state(for error: NWError) -> DiscoveryState {
        guard case .dns(let code) = error else {
            return .failed(error.localizedDescription)
        }
        return switch code {
        case policyDenied, defunctConnection: .localNetworkDenied
        default: .failed(error.localizedDescription)
        }
    }

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
                    continuation.yield(Self.state(for: error))
                case .failed(let error):
                    // A refusal reaches a re-created browser here rather than in `.waiting`, so the
                    // same mapping has to apply on both paths or reopening the app loses it.
                    continuation.yield(Self.state(for: error))
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
