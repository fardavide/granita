import Foundation
import Security
import Testing

import ClientConnectionData
import CorePairingDomain

/// The three lines between a `SecTrust` and a decision, asserted against a real certificate.
///
/// The certificate is `PinnedServerTrustCertificate`, shared with the first-contact delegate's
/// tests, and it is a **ten-year** one on purpose — the lifetime the default TLS policy refuses
/// outright. So a delegate that ever reintroduced `SecTrustEvaluateWithError` alongside the pin
/// would turn the first test here red, which is the only cheap way to keep that mistake from
/// coming back.
struct PinnedServerTrustTests {

    // MARK: - What the delegate decides

    @Test func `given the pinned certificate when the challenge is judged then it is accepted`() throws {
        // given
        let scenario = Scenario(pinned: Scenario.certificateFingerprint)

        // when
        let disposition = scenario.judge(try scenario.trust())

        // then
        // A ten-year certificate, accepted. The default policy would refuse this one for its whole
        // life, so this passing is the evidence that no default evaluation runs beside the pin.
        #expect(disposition == .useCredential)
    }

    @Test func `given a certificate the phone did not pin when the challenge is judged then it is refused`() throws {
        // given
        let scenario = Scenario(pinned: SpkiFingerprint(rawValue: "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ="))

        // when
        let disposition = scenario.judge(try scenario.trust())

        // then
        // Another Mac's certificate, perfectly well-formed, and not the one this phone paired with.
        #expect(disposition == .cancelAuthenticationChallenge)
    }

    @Test func `given a challenge that is not about server trust when it is judged then it is not answered here`() {
        // given
        let scenario = Scenario(pinned: Scenario.certificateFingerprint)

        // when
        let disposition = scenario.judge(method: NSURLAuthenticationMethodHTTPBasic, trust: nil)

        // then
        // Anything that is not server trust is the framework's to handle. Cancelling here would
        // refuse challenges this app never issues an opinion about.
        #expect(disposition == .performDefaultHandling)
    }

    @Test func `given a server trust challenge carrying no trust when it is judged then it is refused`() {
        // given
        let scenario = Scenario(pinned: Scenario.certificateFingerprint)

        // when
        let disposition = scenario.judge(method: NSURLAuthenticationMethodServerTrust, trust: nil)

        // then
        // Refused rather than defaulted: falling through to default handling on a server-trust
        // challenge is exactly the evaluation this type exists to replace.
        #expect(disposition == .cancelAuthenticationChallenge)
    }
}

// MARK: -

private struct Scenario {

    let pinned: SpkiFingerprint

    static let certificateFingerprint = PinnedServerTrustCertificate.fingerprint

    func judge(_ trust: SecTrust) -> URLSession.AuthChallengeDisposition {
        judge(method: NSURLAuthenticationMethodServerTrust, trust: trust)
    }

    func judge(method: String, trust: SecTrust?) -> URLSession.AuthChallengeDisposition {
        PinnedServerTrust(pinnedTo: pinned).disposition(forAuthenticationMethod: method, trust: trust).disposition
    }

    func trust() throws -> SecTrust {
        let certificate = try #require(
            SecCertificateCreateWithData(nil, Data(PinnedServerTrustCertificate.der) as CFData)
        )
        var trust: SecTrust?
        _ = SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust)
        return try #require(trust)
    }
}
