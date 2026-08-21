import Network
import Testing

import ClientConnectionDomain
@testable import ClientConnectionData

/// iOS reports a refused local network permission as one of two DNS codes, and the second one is
/// also what every browser sees when the app is resumed after being suspended. These pin down which
/// of the two says "refused" on its own and which one has to earn it.
@Suite("Browser restart policy")
struct BrowserRestartPolicyTests {

    @Test
    func `given permission was refused when the browser waits then it reads as refusal`() {
        // given — the first browser an app creates sits in .waiting carrying this rather than dying.
        let error = NWError.dns(-65570)

        // when - then
        #expect(BrowserRestartPolicy.stateWhileWaiting(on: error) == .localNetworkDenied)
    }

    @Test
    func `given an unrelated error when the browser waits then it is reported as a failure`() {
        // given
        let error = NWError.posix(.ENETDOWN)

        // when
        let state = BrowserRestartPolicy.stateWhileWaiting(on: error)

        // then — anything we cannot attribute stays a failure, so a real fault is never disguised as
        // a permission problem the reader would go looking for in Settings.
        #expect(state != .localNetworkDenied)
        if case .failed = state {} else {
            Issue.record("expected a failure state, got \(state)")
        }
    }

    @Test
    func `given the app was suspended when the browser dies once then the reader is told nothing`() {
        // given — a resumed process has lost mDNSResponder, and every browser it left running dies
        // with this. Reported as a refusal it put "Local network access is off" in front of Davide
        // on a device where it was on.
        var sut = BrowserRestartPolicy()

        // when
        let restart = sut.restart(after: .dns(-65569))

        // then
        #expect(restart.report == nil)
    }

    @Test
    func `given a browser keeps dying with a defunct connection when it will not come back then it reads as refusal`() {
        // given
        var sut = BrowserRestartPolicy()

        // when
        _ = sut.restart(after: .dns(-65569))
        _ = sut.restart(after: .dns(-65569))
        let restart = sut.restart(after: .dns(-65569))

        // then — a browser that cannot be replaced is the shape of a refusal, and it is the only
        // shape a reopened app gets to see.
        #expect(restart.report == .localNetworkDenied)
    }

    @Test
    func `given a replacement browser worked when a later one dies then the count starts over`() {
        // given — the app went to the background twice, which is not the same as being refused twice.
        var sut = BrowserRestartPolicy()
        _ = sut.restart(after: .dns(-65569))
        _ = sut.restart(after: .dns(-65569))

        // when
        sut.recordReady()
        let restart = sut.restart(after: .dns(-65569))

        // then
        #expect(restart.report == nil)
    }

    @Test
    func `given permission was refused when the browser dies then it reads as refusal at once`() {
        // given — this code is unambiguous wherever it turns up, so it is not worth counting.
        var sut = BrowserRestartPolicy()

        // when
        let restart = sut.restart(after: .dns(-65570))

        // then
        #expect(restart.report == .localNetworkDenied)
    }

    @Test
    func `given an unrelated error when the browser dies then it is reported as a failure`() {
        // given
        var sut = BrowserRestartPolicy()

        // when
        let restart = sut.restart(after: .posix(.ENETDOWN))

        // then — a fault we cannot attribute is shown as itself. Calling it a refusal would send the
        // reader to a Settings switch that is already on.
        #expect(restart.report == .failed(NWError.posix(.ENETDOWN).localizedDescription))
    }

    @Test
    func `given an unfamiliar dns error when the browser dies then it is reported as a failure`() {
        // given — the two codes this file is about are not the only ones the resolver has.
        let error = NWError.dns(-65_563)
        var sut = BrowserRestartPolicy()

        // when
        let restart = sut.restart(after: error)

        // then
        #expect(restart.report == .failed(error.localizedDescription))
    }

    @Test
    func `given a refusal was diagnosed when browsers keep dying then they are replaced less often`() {
        // given
        var sut = BrowserRestartPolicy()
        let firstDeath = sut.restart(after: .dns(-65569))

        // when — replacements past this point exist only to notice the permission being granted.
        _ = sut.restart(after: .dns(-65569))
        let diagnosed = sut.restart(after: .dns(-65569))

        // then
        #expect(diagnosed.delay > firstDeath.delay)
        #expect(firstDeath.delay > .zero)
    }
}
