import Testing

import ServerApiDomain
import ServerStoreDomain
@testable import ServerApiPresentation

@Suite("Observed server host")
struct ObservingServerHostTests {
    @Test
    func `given a host finishes when its states end then observation and preparation are stopped and joined`() async {
        // given
        let scenario = Scenario()
        var states = scenario.sut.run().makeAsyncIterator()
        let first = await states.next()
        await scenario.observation.waitUntilStarted()
        await scenario.preparation.waitUntilStarted()

        // when
        scenario.host.finish()
        let last = await states.next()

        // then
        #expect(first == .starting)
        #expect(last == nil)
        #expect(await scenario.observation.stopCount == 1)
        #expect(await scenario.observation.didFinish)
        #expect(await scenario.preparation.didFinish)
    }

    @Test
    func `given another process owns the store when serving is requested then no background work starts`() async {
        // given
        let scenario = Scenario()
        let locked = StoreLockingServerHost(host: scenario.sut, lock: FakeStoreLock())

        // when
        var states: [ServerRunState] = []
        for await state in locked.run() { states.append(state) }

        // then
        #expect(states == [.blockedByAnotherProcess(nil)])
        #expect(scenario.host.runCount == 0)
        #expect(await scenario.observation.runCount == 0)
        #expect(await scenario.preparation.runCount == 0)
    }

    private struct Scenario {
        let host = FakeServerHost()
        let observation = FakeWorktreeObserving()
        let preparation = FakeServerPreparation()
        let sut: ObservingServerHost

        init() {
            let preparation = preparation
            sut = ObservingServerHost(
                host: host,
                observation: observation,
                wakes: FakeWakeNotifications(),
                preparing: { await preparation.run() }
            )
        }
    }
}

private struct FakeStoreLock: StoreLocking {
    func acquire() async -> StoreLockOutcome { .heldBy(nil) }
}
