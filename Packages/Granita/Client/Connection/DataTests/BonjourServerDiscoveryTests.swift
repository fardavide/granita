import Testing

import ClientConnectionDomain
@testable import ClientConnectionData

@Suite("Bonjour server discovery")
struct BonjourServerDiscoveryTests {

    @Test(.timeLimit(.minutes(1)))
    func `when discovery starts then it says it is looking before any browser has reported`() async {
        // given — a browser that reports nothing, ever. That is the precondition the question needs:
        // *before any browser has reported* is only asserted if none has.
        //
        // It used to be a real `NWBrowser`, and the test passed either way — what varied was how much
        // of this file and of `BonjourBrowser` ran before the loop was left, which moved the coverage
        // gate between runs of identical code. A test that answers the machine it runs on is the one
        // failure a percentage cannot describe.
        let sut = BonjourServerDiscovery(makeBrowser: { FakeServiceBrowser(events: []) })

        // when
        var first: DiscoveryState?
        for await state in sut.discover() {
            first = state
            break
        }

        // then — the screen must say something the moment it opens. Waiting for the browser would
        // leave it on the idle state for as long as the daemon takes to answer.
        #expect(first == .searching)
    }
}
