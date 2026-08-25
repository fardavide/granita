import Foundation
import Security
import Testing

import ClientConnectionData
import CorePairingDomain

/// The delegate for a Mac nobody vouched for, asserted against the same real certificate the pinned
/// one is judged with.
///
/// **Read these as the definition of what trust on first use costs and what it does not.** It
/// accepts a certificate it was told nothing about, which is the risk; it records exactly what it
/// accepted and refuses to forget or replace it, which is what keeps the risk one exchange long.
/// A change that widened either half would turn one of these red.
struct FirstContactServerTrustTests {

    @Test func `given a certificate nothing vouched for when the challenge is judged then it is accepted`() async throws {
        // given — the whole point. There is no pin to compare against, because the six words that
        // got the reader here carry a code and nothing else.
        let sut = FirstContactServerTrust()

        // when
        let answer = await sut.disposition(
            forAuthenticationMethod: NSURLAuthenticationMethodServerTrust,
            trust: try aCertificate()
        )

        // then
        #expect(answer.disposition == .useCredential)
    }

    @Test func `given a certificate was accepted then the key it carried is what would be pinned`() async throws {
        // given — and this is the load-bearing one: the fingerprint the repository's own transport
        // is pinned to afterwards comes from here, so it has to be the key that was actually on the
        // wire rather than anything reconstructed.
        let sut = FirstContactServerTrust()

        // when
        _ = await sut.disposition(
            forAuthenticationMethod: NSURLAuthenticationMethodServerTrust,
            trust: try aCertificate()
        )

        // then — the same string `openssl` produced for this certificate's public key, which is what
        // the pinned delegate would have compared against had a QR carried it.
        #expect(await sut.fingerprint() == certificateFingerprint)
    }

    @Test func `given nothing has been spoken to then there is no key to report`() async {
        // given
        let sut = FirstContactServerTrust()

        // when - then
        // Nothing may build a pinned session from a handshake that has not happened.
        #expect(await sut.fingerprint() == nil)
    }

    @Test func `given a second certificate arrives when it is judged then the first key still stands`() async throws {
        // given — a session challenged twice mid-pairing. Adopting the second answer would make a
        // first-contact delegate a moving target, which is the one way this could be turned into
        // something strictly worse than no pinning at all.
        let sut = FirstContactServerTrust()
        _ = await sut.disposition(
            forAuthenticationMethod: NSURLAuthenticationMethodServerTrust,
            trust: try aCertificate()
        )

        // when
        _ = await sut.disposition(
            forAuthenticationMethod: NSURLAuthenticationMethodServerTrust,
            trust: try anotherCertificate()
        )

        // then
        #expect(await sut.fingerprint() == certificateFingerprint)
    }

    @Test func `given a challenge that is not about server trust when it is judged then it is not answered here`() async {
        // given
        let sut = FirstContactServerTrust()

        // when
        let answer = await sut.disposition(forAuthenticationMethod: NSURLAuthenticationMethodHTTPBasic, trust: nil)

        // then
        #expect(answer.disposition == .performDefaultHandling)
        #expect(await sut.fingerprint() == nil)
    }

    @Test func `given a server trust challenge carrying no trust when it is judged then it is refused`() async {
        // given
        let sut = FirstContactServerTrust()

        // when
        let answer = await sut.disposition(forAuthenticationMethod: NSURLAuthenticationMethodServerTrust, trust: nil)

        // then
        // Refused rather than defaulted, and refused rather than accepted-and-forgotten: a handshake
        // this phone cannot describe afterwards is one it must not pin from.
        #expect(answer.disposition == .cancelAuthenticationChallenge)
        #expect(await sut.fingerprint() == nil)
    }

    // MARK: -

    /// The same ten-year self-signed P-256 certificate `PinnedServerTrustTests` judges, so the two
    /// delegates are demonstrably looking at one key and disagreeing only about what to do with it.
    private func aCertificate() throws -> SecTrust {
        try trust(over: PinnedServerTrustCertificate.der)
    }

    /// A different Mac. Well-formed, and not the one first contact met.
    private func anotherCertificate() throws -> SecTrust {
        try trust(over: PinnedServerTrustCertificate.otherDer)
    }

    private func trust(over der: [UInt8]) throws -> SecTrust {
        let certificate = try #require(SecCertificateCreateWithData(nil, Data(der) as CFData))
        var trust: SecTrust?
        _ = SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)
        return try #require(trust)
    }

    private let certificateFingerprint = PinnedServerTrustCertificate.fingerprint
}
