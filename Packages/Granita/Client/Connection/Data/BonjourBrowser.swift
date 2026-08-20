import Dispatch
import Network

import ClientConnectionDomain
import CoreBrandingDomain

/// A real `NWBrowser`, with its two callbacks turned into one stream that ends when it does.
final class BonjourBrowser: ServiceBrowsing {

    /// Browsing has no reason to be on the main queue: what the events reach is a main-actor view
    /// model, and the hop happens at its `await` rather than here. Off the main queue they also
    /// arrive in a host test, whose main thread belongs to the test runner.
    private static let queue = DispatchQueue(label: "granita.discovery.browser")

    private let browser: NWBrowser

    init() {
        browser = NWBrowser(
            for: .bonjour(type: Branding.bonjourServiceType, domain: nil),
            using: .tcp
        )
    }

    /// What a browser's state means to the session listening to it.
    ///
    /// Separated from the callback it is read in because that one runs only against a real network,
    /// and which states are a browser's last is the part the session's whole restart loop turns on.
    static func change(for state: NWBrowser.State) -> BrowserStateChange {
        switch state {
        case .setup:
            .ignore
        case .ready:
            .report(.ready)
        case .waiting(let error):
            .report(.waiting(error))
        case .failed(let error):
            .reportAndFinish(.failed(error))
        case .cancelled:
            .finish
        @unknown default:
            .ignore
        }
    }

    func start() -> AsyncStream<BrowserEvent> {
        AsyncStream { continuation in
            browser.stateUpdateHandler = { state in
                switch Self.change(for: state) {
                case .ignore:
                    break
                case .report(let event):
                    continuation.yield(event)
                case .reportAndFinish(let event):
                    continuation.yield(event)
                    continuation.finish()
                case .finish:
                    continuation.finish()
                }
            }
            browser.browseResultsChangedHandler = { results, _ in
                continuation.yield(.found(results.compactMap(Self.server(from:))))
            }
            browser.start(queue: Self.queue)
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

// MARK: -

/// What a browser's state change asks of the stream carrying its events.
enum BrowserStateChange: Equatable {
    case ignore
    case report(BrowserEvent)
    /// The last thing this browser will say, and then it is finished.
    case reportAndFinish(BrowserEvent)
    /// Finished with nothing to add: a cancelled browser was stopped on purpose.
    case finish
}
