import ClientConnectionDomain
import Network
import Testing

@testable import ClientConnectionData

/// iOS reports a refused local network permission in two different ways depending on whether the
/// browser is the first one the app has created, and the second way is what a reopened app sees.
@Suite("Bonjour discovery failures")
struct BonjourDiscoveryFailureTests {

    @Test
    func `given permission was refused when browsing the first time then it reads as refusal`() {
        // given — the browser sits in .waiting carrying this rather than failing outright.
        let error = NWError.dns(-65570)

        // when - then
        #expect(BonjourServerDiscovery.state(for: error) == .localNetworkDenied)
    }

    @Test
    func `given permission was refused when reopening the app then it still reads as refusal`() {
        // given — a browser re-created after a refusal cannot reach mDNSResponder at all and fails
        // with DefunctConnection. Unrecognised, this surfaced to Davide as a raw NWError string.
        let error = NWError.dns(-65569)

        // when - then
        #expect(BonjourServerDiscovery.state(for: error) == .localNetworkDenied)
    }

    @Test
    func `given an unrelated network error when browsing then it is reported as a failure`() {
        // given
        let error = NWError.posix(.ENETDOWN)

        // when
        let state = BonjourServerDiscovery.state(for: error)

        // then — anything we cannot attribute stays a failure, so a real fault is never disguised
        // as a permission problem the reader would go looking for in Settings.
        #expect(state != .localNetworkDenied)
        if case .failed = state {} else {
            Issue.record("expected a failure state, got \(state)")
        }
    }
}
