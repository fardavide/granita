import Network

import ClientConnectionDomain
import CoreBrandingDomain

/// A real `NWBrowser`, with its two callbacks turned into one stream that ends when it does.
final class BonjourBrowser: ServiceBrowsing {

    private let browser: NWBrowser

    init() {
        browser = NWBrowser(
            for: .bonjour(type: Branding.bonjourServiceType, domain: nil),
            using: .tcp
        )
    }

    func start() -> AsyncStream<BrowserEvent> {
        AsyncStream { continuation in
            browser.stateUpdateHandler = { state in
                switch state {
                case .setup:
                    break
                case .ready:
                    continuation.yield(.ready)
                case .waiting(let error):
                    continuation.yield(.waiting(error))
                case .failed(let error):
                    continuation.yield(.failed(error))
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
            browser.start(queue: .main)
        }
    }

    func cancel() {
        browser.cancel()
    }

    /// Only service endpoints carry a name, and a name is the identity — anything else is not a
    /// server we can address later.
    private static func server(from result: NWBrowser.Result) -> DiscoveredServer? {
        guard case .service(let name, _, _, _) = result.endpoint else { return nil }
        return DiscoveredServer(id: name, name: name)
    }
}
