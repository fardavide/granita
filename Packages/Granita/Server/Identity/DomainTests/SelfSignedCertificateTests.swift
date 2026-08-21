import CryptoKit
import Foundation
import Security
import Testing

import CorePairingDomain
import ServerIdentityDomain

/// The certificate this Mac serves under.
///
/// Almost nothing here is asserted against our own encoder. The certificate is handed to
/// **Security.framework** and the assertions are about what *it* reads back — the name, the key,
/// the addresses, and whether the signature holds up under a real TLS policy. That is deliberate:
/// a certificate this repository is happy with and the system is not is precisely the failure that
/// shows up as a handshake refused on a phone with no further explanation.
struct SelfSignedCertificateTests {

    // MARK: - What the system reads back

    @Test func `when building an identity then macos parses the certificate it produced`() throws {
        // given
        let scenario = Scenario()

        // when
        let identity = try scenario.identity()

        // then
        #expect(scenario.parsed(identity) != nil)
    }

    @Test func `when building an identity then the certificate carries the name it was given`() throws {
        // given
        let scenario = Scenario(commonName: "Davide's MacBook Pro")

        // when
        let identity = try scenario.identity()

        // then
        let certificate = try #require(scenario.parsed(identity))
        var name: CFString?
        SecCertificateCopyCommonName(certificate, &name)
        #expect(name as String? == "Davide's MacBook Pro")
    }

    @Test func `when building an identity then the certificate carries the key it was signed with`() throws {
        // given
        let scenario = Scenario()

        // when
        let identity = try scenario.identity()

        // then
        let certificate = try #require(scenario.parsed(identity))
        let readBack = try #require(SecCertificateCopyKey(certificate))
        let bytes = try #require(SecKeyCopyExternalRepresentation(readBack, nil) as Data?)
        #expect(Array(bytes) == Array(scenario.key.publicKey.x963Representation))
    }

    @Test func `when building an identity then its fingerprint is of the key inside the certificate`() throws {
        // given
        let scenario = Scenario()

        // when
        let identity = try scenario.identity()

        // then
        #expect(
            identity.fingerprint
                == SpkiFingerprint(subjectPublicKeyInfoDer: scenario.key.publicKey.derRepresentation)
        )
    }

    // MARK: - The signature

    @Test func `given a certificate when evaluating it as its own anchor then the signature holds`() throws {
        // given
        let scenario = Scenario()

        // when
        let refusal = try scenario.trustRefusal(scenario.identity(), forHost: nil)

        // then
        // The strongest thing this suite says. A byte wrong anywhere inside the signed body and the
        // system cannot verify it against the key the certificate itself carries — which is what
        // every length, every integer pad and every tag in the encoder is for.
        #expect(refusal == nil)
    }

    @Test func `given a certificate that has expired when evaluating it then the system refuses it`() throws {
        // given
        let longAgo = Date(timeIntervalSince1970: 1_000_000_000)
        let scenario = Scenario(notBefore: longAgo, notAfter: longAgo.addingTimeInterval(60))

        // when
        let refusal = try scenario.trustRefusal(scenario.identity(), forHost: nil)

        // then
        #expect(refusal?.contains("not temporally valid") == true)
    }

    // MARK: - The names, matched by the system's own matcher

    @Test func `given a name the certificate covers when matching a host then the system does not object to it`() throws {
        // given
        let scenario = Scenario(
            subjectAlternativeNames: [.dnsName("granita-test.local"), .ipAddress(IpAddress(bytes: [192, 168, 1, 42]))]
        )

        // when
        let refusal = try scenario.trustRefusal(scenario.identity(), forHost: "granita-test.local")

        // then
        #expect(refusal?.contains("hostname does not match") != true)
    }

    @Test func `given a name the certificate does not cover when matching a host then the system says so`() throws {
        // given
        let scenario = Scenario(subjectAlternativeNames: [.dnsName("granita-test.local")])

        // when
        let refusal = try scenario.trustRefusal(scenario.identity(), forHost: "someone-elses-mac.local")

        // then
        // The mirror of the test above, and the reason it is worth having: a subject alternative
        // name that was never encoded at all looks exactly like one that matches everything.
        #expect(refusal?.contains("hostname does not match") == true)
    }

    @Test func `given an address the certificate covers when matching a host then the system does not object to it`() throws {
        // given
        let scenario = Scenario(
            subjectAlternativeNames: [.dnsName("granita-test.local"), .ipAddress(IpAddress(bytes: [192, 168, 1, 42]))]
        )

        // when
        let refusal = try scenario.trustRefusal(scenario.identity(), forHost: "192.168.1.42")

        // then
        // A Bonjour name is the usual way in and an address is the fallback when mDNS is not
        // bridged between two segments of a network, which is the arrangement Davide actually has.
        #expect(refusal?.contains("hostname does not match") != true)
    }

    // MARK: - Validity, and what macOS thinks of ten years of it

    @Test func `when building an identity for ten years then it expires ten years after it starts`() throws {
        // given
        let start = Date(timeIntervalSince1970: 1_771_632_000)
        let scenario = Scenario(notBefore: start, notAfter: start.addingTimeInterval(ServerIdentity.tenYears))

        // when
        let identity = try scenario.identity()

        // then
        #expect(identity.notBefore == start)
        #expect(identity.notAfter.timeIntervalSince(start) / (365 * 24 * 60 * 60) > 9.9)
    }

    @Test func `given the ten year certificate when the default tls policy judges it then it is refused for its lifetime`() throws {
        // given
        let now = Date()
        let scenario = Scenario(notBefore: now, notAfter: now.addingTimeInterval(ServerIdentity.tenYears))

        // when
        let refusal = try scenario.trustRefusal(scenario.identity(), forHost: "granita-test.local")

        // then
        // **TRAP, and the reason the client pins rather than evaluates.** macOS caps a TLS server
        // certificate at 398 days and applies that cap even to a certificate handed to it as its
        // own anchor — the published exemption covers roots a human installed, not one set
        // programmatically. So a client that ran the default evaluation *and* compared the
        // fingerprint would refuse every Granita on earth, and SPEC §8's ten years and its pinning
        // are one decision rather than two.
        //
        // Asserted rather than worked around, so that a macOS which changes its mind turns this
        // red instead of leaving a comment nobody re-checks.
        #expect(refusal?.contains("exceeds maximum temporal validity") == true)
    }

    // MARK: - Serial numbers

    @Test func `given two identities from different serials then the certificates differ`() throws {
        // given
        let scenario = Scenario()

        // when
        let one = try scenario.identity(serialNumber: [0x01, 0x02, 0x03, 0x04])
        let other = try scenario.identity(serialNumber: [0x05, 0x06, 0x07, 0x08])

        // then
        #expect(one.certificateDer != other.certificateDer)
    }

    // MARK: - Refusals

    @Test func `given an address that is neither four bytes nor sixteen when building then it is refused`() throws {
        // given
        let scenario = Scenario(subjectAlternativeNames: [.ipAddress(IpAddress(bytes: [10, 0, 1]))])

        // when - then
        #expect(throws: ServerIdentityError.malformedSubject(reason: "an IP address of 3 bytes")) {
            try scenario.identity()
        }
    }

    @Test func `given a name outside ascii when building then it is refused rather than mangled`() throws {
        // given
        // A DNS name is IA5String, which has no room for this at all — and a certificate whose SAN
        // silently lost its accents is one that matches no host.
        let scenario = Scenario(subjectAlternativeNames: [.dnsName("caffè.local")])

        // when - then
        #expect(throws: ServerIdentityError.malformedSubject(reason: "a DNS name outside ASCII: caffè.local")) {
            try scenario.identity()
        }
    }

    // MARK: -

    private struct Scenario {

        let key = P256.Signing.PrivateKey()

        private let commonName: String
        private let subjectAlternativeNames: [SubjectAlternativeName]
        private let notBefore: Date
        private let notAfter: Date

        init(
            commonName: String = "Granita Test",
            subjectAlternativeNames: [SubjectAlternativeName] = [.dnsName("granita-test.local")],
            notBefore: Date = Date(timeIntervalSince1970: 1_771_632_000),
            notAfter: Date = Date(timeIntervalSince1970: 1_771_632_000 + ServerIdentity.tenYears)
        ) {
            self.commonName = commonName
            self.subjectAlternativeNames = subjectAlternativeNames
            self.notBefore = notBefore
            self.notAfter = notAfter
        }

        func identity(serialNumber: [UInt8] = [0x2a, 0x2a, 0x2a, 0x2a]) throws(ServerIdentityError) -> ServerIdentity {
            try SelfSignedCertificate.identity(
                signedBy: key,
                commonName: commonName,
                subjectAlternativeNames: subjectAlternativeNames,
                serialNumber: serialNumber,
                notBefore: notBefore,
                notAfter: notAfter
            )
        }

        func parsed(_ identity: ServerIdentity) -> SecCertificate? {
            SecCertificateCreateWithData(nil, Data(identity.certificateDer) as CFData)
        }

        /// Why the system refused this certificate, or `nil` if it did not.
        ///
        /// Anchored to itself deliberately: a self-signed certificate chains to nothing, so the
        /// question worth asking is not "does the system trust this issuer" — nothing does — but
        /// "does everything inside hold together once you decide to".
        ///
        /// The reason rather than a boolean, because the answers here are not one thing. A
        /// ten-year certificate is refused for its lifetime whatever else is right with it, so a
        /// test that read only the verdict could not tell a name that fails to match from a
        /// signature that fails to verify.
        ///
        /// - Parameter host: The name to match, or `nil` to judge the certificate alone. The
        ///   hostname rule lives in the TLS policy and nowhere else.
        func trustRefusal(_ identity: ServerIdentity, forHost host: String?) throws -> String? {
            let certificate = try #require(parsed(identity))
            let policy = host.map { SecPolicyCreateSSL(true, $0 as CFString) } ?? SecPolicyCreateBasicX509()

            var trust: SecTrust?
            SecTrustCreateWithCertificates(certificate, policy, &trust)
            let evaluated = try #require(trust)
            SecTrustSetAnchorCertificates(evaluated, [certificate] as CFArray)
            SecTrustSetAnchorCertificatesOnly(evaluated, true)

            var refusal: CFError?
            guard SecTrustEvaluateWithError(evaluated, &refusal) == false else { return nil }
            return "\(refusal.map { "\($0)" } ?? "refused with no reason given")"
        }
    }
}
