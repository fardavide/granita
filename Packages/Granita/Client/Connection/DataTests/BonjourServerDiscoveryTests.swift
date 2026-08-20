import Testing

import ClientConnectionDomain
@testable import ClientConnectionData

@Suite("Bonjour server discovery")
struct BonjourServerDiscoveryTests {

    @Test(.timeLimit(.minutes(1)))
    func `when discovery starts then it says it is looking before any browser has reported`() async {
        // given
        let sut = BonjourServerDiscovery()

        // when — the real browser behind this finds nothing on a build machine, so only the first
        // state is taken: it is the one that does not depend on the network. Leaving the loop tears
        // the stream down, which cancels the session and the browser with it.
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
