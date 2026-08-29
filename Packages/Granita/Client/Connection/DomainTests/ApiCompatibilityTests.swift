import Testing

import ClientConnectionDomain
import CoreApiDomain
import CoreBrandingDomain

/// The two apps ship through different pipelines, so one of them is out of date sooner or later.
/// `/v1/health` is the only route that answers before pairing, which makes it the one place the
/// mismatch can be caught before a reader has spent a code on it.
@Suite("Api compatibility")
struct ApiCompatibilityTests {

    @Test
    func `given a Mac serving this contract when its health is read then the two agree`() {
        // given
        let health = HealthResponse(
            name: "Granita",
            apiVersion: Branding.apiVersion,
            serverVersion: "0.0.9",
            wakeAddresses: nil
        )

        // when - then
        #expect(health.compatibility == .sameContract)
    }

    @Test
    func `given a Mac serving an older contract when its health is read then the Mac is behind`() {
        // given — the Mac app is notarised by hand and the phone app ships to TestFlight on every
        // merge, so this is the direction skew actually goes.
        let health = HealthResponse(
            name: "Granita",
            apiVersion: Branding.apiVersion - 1,
            serverVersion: "0.0.1",
            wakeAddresses: nil
        )

        // when - then
        #expect(health.compatibility == .macIsBehind(serving: Branding.apiVersion - 1))
    }

    @Test
    func `given a Mac serving a newer contract when its health is read then the phone is behind`() {
        // given
        let health = HealthResponse(
            name: "Granita",
            apiVersion: Branding.apiVersion + 1,
            serverVersion: "9.9.9",
            wakeAddresses: nil
        )

        // when - then — naming which end is behind is not pedantry: one of them is fixed by opening
        // the App Store and the other by opening a Mac, and a single "versions differ" sends the
        // reader to whichever they guess.
        #expect(health.compatibility == .phoneIsBehind(serving: Branding.apiVersion + 1))
    }
}
