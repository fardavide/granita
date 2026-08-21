import CryptoKit
import Foundation
import Testing

import CorePairingDomain

/// The decision the phone makes about a Mac's certificate, with the framework taken out of it.
///
/// **This is the whole of the trust evaluation, deliberately.** The delegate that calls it does
/// nothing but read the leaf key out of a `SecTrust` and turn the answer into a disposition, because
/// the default TLS policy refuses a ten-year certificate outright — `ServerIdentityDomainTests`
/// asserts that refusal against the real policy — and a client that ran both would refuse every
/// Granita there has ever been. There is no evaluation to fall back to, so there is nothing here to
/// combine with one.
///
/// The key arrives in the X9.63 form `SecKeyCopyExternalRepresentation` hands back, and the
/// fingerprint is taken over the `SubjectPublicKeyInfo` CryptoKit re-encodes it into — the same
/// bytes the Mac hashed when it wrote the pairing link, rather than a second opinion about what a
/// public key is.
struct PinnedTrustTests {

    // MARK: - The decision

    @Test func `given the pinned mac's own key when judged then it is trusted`() throws {
        // given
        let scenario = Scenario()

        // when
        let trusted = PinnedTrust.isTrusted(
            leafPublicKeyX963: scenario.mac.publicKey.x963Representation,
            against: scenario.pinned
        )

        // then
        #expect(trusted)
    }

    @Test func `given another mac's key when judged then it is refused`() throws {
        // given
        let scenario = Scenario()

        // when
        let trusted = PinnedTrust.isTrusted(
            leafPublicKeyX963: P256.Signing.PrivateKey().publicKey.x963Representation,
            against: scenario.pinned
        )

        // then
        // The whole point of pinning: another Granita on the same network, serving a certificate
        // that is every bit as valid as this one, is still not the Mac this phone paired with.
        #expect(trusted == false)
    }

    @Test func `given bytes that are not a p256 point when judged then it is refused`() {
        // given
        let scenario = Scenario()

        // when
        let trusted = PinnedTrust.isTrusted(
            leafPublicKeyX963: Data("not a public key".utf8),
            against: scenario.pinned
        )

        // then
        // Refused rather than thrown. A handshake this phone cannot make sense of is a handshake it
        // declines, and there is nothing a reader could do with the distinction.
        #expect(trusted == false)
    }

    @Test func `given the vector key when judged against the fingerprint openssl produced then it is trusted`() throws {
        // given
        let key = try P256.Signing.PrivateKey(rawRepresentation: Data(vectorPrivateKey))

        // when
        let trusted = PinnedTrust.isTrusted(
            leafPublicKeyX963: key.publicKey.x963Representation,
            against: SpkiFingerprint(rawValue: "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ=")
        )

        // then
        // Anchored to `openssl`, not to our own encoder, for the reason `SpkiFingerprintTests`
        // gives: a round trip through this repository would agree with itself however wrong it was.
        #expect(trusted)
    }

    // MARK: - Comparing in constant time

    @Test func `given two fingerprints of the same key then they match`() throws {
        // given
        let key = P256.Signing.PrivateKey()

        // when
        let one = SpkiFingerprint(subjectPublicKeyInfoDer: key.publicKey.derRepresentation)
        let other = SpkiFingerprint(subjectPublicKeyInfoDer: key.publicKey.derRepresentation)

        // then
        #expect(one.matches(other))
    }

    @Test func `given fingerprints that differ only in their last character then they do not match`() {
        // given
        let pinned = SpkiFingerprint(rawValue: "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ=")

        // when
        let offered = SpkiFingerprint(rawValue: "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXR=")

        // then
        // The case a comparison that returns on the first difference gets right and leaks the
        // position of, which over a LAN is a practical attack rather than a theoretical one.
        #expect(pinned.matches(offered) == false)
    }

    @Test func `given fingerprints that differ only in their first character then they do not match`() {
        // given
        let pinned = SpkiFingerprint(rawValue: "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ=")

        // when
        let offered = SpkiFingerprint(rawValue: "J5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ=")

        // then
        #expect(pinned.matches(offered) == false)
    }

    @Test func `given fingerprints of different lengths then they do not match`() {
        // given
        let pinned = SpkiFingerprint(rawValue: "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ=")

        // when
        let offered = SpkiFingerprint(rawValue: "I5uJ")

        // then
        #expect(pinned.matches(offered) == false)
    }

    @Test func `given an empty fingerprint then nothing matches it`() {
        // given
        let pinned = SpkiFingerprint(rawValue: "")

        // when
        let offered = SpkiFingerprint(subjectPublicKeyInfoDer: P256.Signing.PrivateKey().publicKey.derRepresentation)

        // then
        // A link that carried no `spki=` at all must not become a link that trusts everything.
        #expect(pinned.matches(offered) == false)
        #expect(offered.matches(pinned) == false)
    }
}

// MARK: -

private struct Scenario {

    let mac = P256.Signing.PrivateKey()

    var pinned: SpkiFingerprint {
        SpkiFingerprint(subjectPublicKeyInfoDer: mac.publicKey.derRepresentation)
    }
}
