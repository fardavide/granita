import Foundation
import Testing

import ServerApiDomain
import ServerApiPresentation

/// A laptop that slept is the single most likely reason the phone cannot reach the Mac, and there
/// is no screen anywhere in this: the whole feature is a loop nobody sees, which is exactly why it
/// is worth a suite.
struct RebindingOnWakeTests {

    @Test func `when nothing has woken then the states are the ones the server underneath reports`() async {
        // given
        let scenario = Scenario()
        var states = scenario.rebinding.run().makeAsyncIterator()

        // when
        let started = await states.next()
        scenario.server.report(.running(.macbook))
        let running = await states.next()

        // then
        #expect(started == .starting)
        #expect(running == .running(.macbook))
        #expect(scenario.server.runCount == 1)
    }

    @Test func `when the mac wakes then a second server is stood up`() async {
        // given
        let scenario = Scenario()
        var states = scenario.rebinding.run().makeAsyncIterator()
        _ = await states.next()
        scenario.server.report(.running(.macbook))
        _ = await states.next()

        // when
        scenario.sleeper.wake()

        // then
        // The state can only have come from a second run, because a run is the only thing that
        // says `starting` — so observing it is observing the rebind rather than timing it.
        #expect(await states.next() == .starting)
        #expect(scenario.server.runCount == 2)
    }

    @Test func `when the mac wakes then the server it was running is torn down first`() async {
        // given
        let scenario = Scenario()
        var states = scenario.rebinding.run().makeAsyncIterator()
        _ = await states.next()

        // when
        scenario.sleeper.wake()
        _ = await states.next()

        // then
        // **A cancelled `ServiceGroup` cannot be restarted**, so waking means a new application —
        // and the old one has to be finished with before the new one asks for the port, or the
        // second bind loses to the first.
        #expect(scenario.server.endedCount == 1)
        #expect(scenario.server.runCount == 2)
    }

    @Test func `when the mac wakes twice then it rebinds twice`() async {
        // given
        let scenario = Scenario()
        var states = scenario.rebinding.run().makeAsyncIterator()
        _ = await states.next()

        // when
        scenario.sleeper.wake()
        _ = await states.next()
        scenario.sleeper.wake()
        _ = await states.next()

        // then
        #expect(scenario.server.runCount == 3)
    }

    @Test func `when whoever was following stops then the server underneath stops with them`() async {
        // given
        let scenario = Scenario()
        let following = Task {
            for await _ in scenario.rebinding.run() {}
        }
        #expect(await scenario.waitUntil { scenario.server.runCount == 1 })

        // when
        following.cancel()
        _ = await following.value

        // then
        // Quitting must not leave a listener behind holding the port the next launch will ask for.
        #expect(await scenario.waitUntil { scenario.server.endedCount == 1 })
    }

    // MARK: -

    private struct Scenario {

        let server = FakeServerHost()
        let sleeper = FakeWakeNotifications()
        let rebinding: RebindingOnWake

        init() {
            rebinding = RebindingOnWake(host: server, wakes: sleeper)
        }

        /// Waits for something that happens on another task, and gives up rather than hanging.
        ///
        /// Used only where the thing being asserted is a teardown, which nothing observable
        /// follows — everywhere else a state arriving is the signal.
        func waitUntil(_ isDone: @Sendable () -> Bool) async -> Bool {
            for _ in 0..<200 {
                if isDone() { return true }
                try? await Task.sleep(for: .milliseconds(5))
            }
            return false
        }
    }
}

// MARK: -

private extension ServerEndpoint {
    static let macbook = ServerEndpoint(host: "macbook.local", port: 8737)
}
