import Network
import Synchronization
import Testing

import ClientConnectionDomain
@testable import ClientConnectionData

/// A browser dies whenever the app is suspended, so the session that outlives it is what decides
/// whether reopening Granita shows the Mac or an accusation about a permission that was never off.
@Suite("Discovery session")
struct DiscoverySessionTests {

    @Test
    func `given the browser died while suspended when the app comes back then a replacement finds the Mac`() async {
        // given — one dead browser and then a working one: what returning from the background looks
        // like on a device where the permission is granted.
        let mac = DiscoveredServer(id: "Davide's MacBook Pro", name: "Davide's MacBook Pro")
        let scenario = Scenario(browsers: [
            [.failed(.dns(-65569))],
            [.ready, .found([mac])]
        ])

        // when
        let states = await scenario.statesUntil(.found([mac]))

        // then — the refusal screen never appeared, and the stream carried on past the death that
        // used to end it.
        #expect(states.contains(.found([mac])))
        #expect(states.contains(.localNetworkDenied) == false)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given permission is refused when every replacement dies too then it is reported`() async {
        // given — one browser, repeated: a refusal is a browser that never comes back.
        let scenario = Scenario(browsers: [[.failed(.dns(-65569))]])

        // when
        let states = await scenario.statesUntil(.localNetworkDenied)

        // then
        #expect(states.last == .localNetworkDenied)
    }

    @Test
    func `given the browser is waiting on a refusal when it is still alive then it is reported without being replaced`() async {
        // given — the first browser an app creates reports a refusal this way and keeps waiting.
        let scenario = Scenario(browsers: [[.waiting(.dns(-65570))]])

        // when
        let states = await scenario.statesUntil(.localNetworkDenied)

        // then
        #expect(states == [.localNetworkDenied])
    }
}

// MARK: -

private struct Scenario {

    let sut: DiscoverySession

    init(browsers: [[BrowserEvent]]) {
        // The last entry repeats, so a test says "and every replacement dies too" by giving one.
        let attempts = Mutex(0)
        sut = DiscoverySession(
            makeBrowser: {
                let attempt = attempts.withLock { count in
                    defer { count += 1 }
                    return min(count, browsers.count - 1)
                }
                return FakeServiceBrowser(events: browsers[attempt])
            },
            wait: { _ in }
        )
    }

    /// Collects what the session reports up to the state the test is waiting for, then tears the
    /// stream down — a session runs until it is cancelled, so nothing else would end it.
    func statesUntil(_ awaited: DiscoveryState) async -> [DiscoveryState] {
        let states = AsyncStream<DiscoveryState> { continuation in
            let session = Task { await sut.run(reporting: continuation) }
            continuation.onTermination = { _ in session.cancel() }
        }
        var reported: [DiscoveryState] = []
        for await state in states {
            reported.append(state)
            if state == awaited { break }
        }
        return reported
    }
}
