import Testing

import CorePairingDomain

@testable import ClientConnectionDomain

/// The one type where the difference between the two credentials is written down, so these are the
/// tests that say what that difference actually is.
@Suite("Pairing attempt")
struct PairingAttemptTests {

    @Test func `given a scanned link then the code and the address come out of it`() {
        // given - when
        let attempt = PairingAttempt.scanned(aLink)

        // then
        #expect(attempt.code == aLink.code)
        #expect(attempt.address == ServerAddress(host: aLink.host, port: aLink.port))
    }

    @Test func `given a scanned link then there is a key to pin before anything is sent`() {
        // given - when
        let attempt = PairingAttempt.scanned(aLink)

        // then
        // The QR travelled over the Mac's own screen, which nobody on the network can write to.
        #expect(attempt.pin == aLink.fingerprint)
    }

    @Test func `given six words then the address is the one the browse resolved`() {
        // given - when
        let attempt = PairingAttempt.spoken(code: sixWords, at: anAddress)

        // then
        #expect(attempt.code == sixWords)
        #expect(attempt.address == anAddress)
    }

    @Test func `given six words then there is no key to pin`() {
        // given - when
        let attempt = PairingAttempt.spoken(code: sixWords, at: anAddress)

        // then
        // **The whole finding of design §5, as one assertion.** The words carry a code and nothing
        // else, so there is nothing to check the answering Mac against and the phone trusts whoever
        // answers. Everything the screens do differently on this path follows from this `nil`.
        #expect(attempt.pin == nil)
    }
}

// MARK: -

private let aLink = PairingLink(
    host: "davides-macbook-pro.local",
    port: 59144,
    code: "9d41e0c7a2b85f36",
    fingerprint: SpkiFingerprint(rawValue: "cf83e1357eefb8bdf1542850d66d8007")
)

private let anAddress = ServerAddress(host: "davides-macbook-pro.local", port: 59144)

private let sixWords = "cabin-cactus-camera-candle-harbour-lantern"
