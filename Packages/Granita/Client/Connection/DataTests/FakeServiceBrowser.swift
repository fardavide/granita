import Network

@testable import ClientConnectionData

/// Reports the events it was handed and then stops, standing in for the one thing a host test cannot
/// have: a real browser reaching a real permission decision.
final class FakeServiceBrowser: ServiceBrowsing {

    private let events: [BrowserEvent]

    init(events: [BrowserEvent]) {
        self.events = events
    }

    func start() -> AsyncStream<BrowserEvent> {
        AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func cancel() {}
}
