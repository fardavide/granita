import Network
import Testing

@testable import ClientConnectionData

/// A browser says five things and two of them are its last. Which is which decides whether the
/// session waits for more or goes and makes a new browser, so it is worth pinning away from the
/// callback it is read in — that one only runs against a real network.
@Suite("Bonjour browser")
struct BonjourBrowserTests {

    @Test
    func `given a browser is coming up when it reports setup then there is nothing to say yet`() {
        // when - then
        #expect(BonjourBrowser.change(for: .setup) == .ignore)
    }

    @Test
    func `when a browser is ready then it is reported and stays open`() {
        // when - then
        #expect(BonjourBrowser.change(for: .ready) == .report(.ready))
    }

    @Test
    func `given a browser cannot proceed when it waits then it is reported and stays open`() {
        // given — a waiting browser is alive and recovers on its own.
        let error = NWError.dns(-65570)

        // when - then
        #expect(BonjourBrowser.change(for: .waiting(error)) == .report(.waiting(error)))
    }

    @Test
    func `given a browser dies when it reports why then that is the last thing it says`() {
        // given
        let error = NWError.dns(-65569)

        // when - then — nothing arrives on a browser past this, so the stream has to end or the
        // session waits forever for a browser that is gone.
        #expect(BonjourBrowser.change(for: .failed(error)) == .reportAndFinish(.failed(error)))
    }

    @Test
    func `given the session went away when the browser is cancelled then it ends with nothing to add`() {
        // when - then
        #expect(BonjourBrowser.change(for: .cancelled) == .finish)
    }
}
