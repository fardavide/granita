import Testing

import ServerApiDomain
@testable import ServerApiPresentation

@Suite("Observed server lifetime")
struct ObservingServerLifetimeTests {
    @Test
    func `given serving finishes when its lifetime returns then observation is stopped and joined`() async {
        // given
        let scenario = Scenario()

        // when
        await scenario.sut.run {
            await scenario.observation.waitUntilStarted()
        }

        // then
        #expect(await scenario.observation.runCount == 1)
        #expect(await scenario.observation.stopCount == 1)
        #expect(await scenario.observation.didFinish)
    }

    @Test
    func `given the Mac wakes while serving when the wake stream drains then inventory is reconciled`() async {
        // given
        let scenario = Scenario(wakes: .finite)

        // when
        await scenario.sut.run {
            await scenario.observation.waitUntilStarted()
            await scenario.wakes.allowFiniteWake()
            // A second finite subscription waits for the first to drain. Without the lifetime
            // subscribing, this drains the wake itself and the reconciliation count stays zero.
            for await _ in scenario.wakes.wakes() {}
        }

        // then
        #expect(await scenario.observation.reconciliationCount == 1)
    }

    @Test
    func `given serving throws when its lifetime ends then the failure survives after observation drains`() async {
        // given
        let scenario = Scenario()

        // when
        await #expect(throws: ServingFailure.refused) {
            try await scenario.sut.run { () async throws(ServingFailure) -> Void in
                await scenario.observation.waitUntilStarted()
                throw .refused
            }
        }

        // then
        #expect(await scenario.observation.stopCount == 1)
        #expect(await scenario.observation.didFinish)
    }

    @Test
    func `given serving is cancelled when its lifetime returns then observation has drained`() async {
        // given
        let scenario = Scenario()
        let host = FakeServerHost()
        let serving = Task {
            await scenario.sut.run {
                for await _ in host.run() {}
            }
        }
        await scenario.observation.waitUntilStarted()

        // when
        serving.cancel()
        await serving.value

        // then
        #expect(await scenario.observation.stopCount == 1)
        #expect(await scenario.observation.didFinish)
    }

    private enum ServingFailure: Error, Equatable {
        case refused
    }

    private struct Scenario {
        let observation = FakeWorktreeObserving()
        let wakes: FakeWakeNotifications
        let sut: ObservingServerLifetime

        init(wakes: FakeWakeNotifications.Delivery = .manual) {
            self.wakes = FakeWakeNotifications(delivery: wakes)
            sut = ObservingServerLifetime(observation: observation, wakes: self.wakes)
        }
    }
}
