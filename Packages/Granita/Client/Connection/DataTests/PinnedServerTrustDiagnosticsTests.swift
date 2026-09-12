import Foundation
import Security
import Testing

import ClientConnectionData
import CorePairingDomain

struct PinnedServerTrustDiagnosticsTests {

    @Test
    func `given the pinned certificate when the session accepts its challenge then copied logs explain the safe trust decision`() async throws {
        // given
        let scenario = Scenario(
            pinned: PinnedServerTrustCertificate.fingerprint,
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )
        let certificate = try #require(
            SecCertificateCreateWithData(nil, Data(PinnedServerTrustCertificate.der) as CFData)
        )
        var trust: SecTrust?
        #expect(SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust) == errSecSuccess)
        let serverTrust: SecTrust = try #require(trust)
        let challenge = URLAuthenticationChallenge(
            protectionSpace: FakeUrlProtectionSpace(host: "100.87.42.19", port: 8737, trust: serverTrust),
            proposedCredential: URLCredential(user: "private-user", password: "private-password", persistence: .none),
            previousFailureCount: 0,
            failureResponse: nil,
            error: NSError(
                domain: "NSURLErrorDomain",
                code: -1200,
                userInfo: [NSLocalizedDescriptionKey: "Bearer private-bearer-token"]
            ),
            sender: FakeUrlAuthenticationChallengeSender()
        )

        // when
        let answer = await withCheckedContinuation { continuation in
            scenario.sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
                continuation.resume(returning: (disposition, credential))
            }
        }
        let report = await scenario.logs.report()

        // then
        #expect(answer.0 == .useCredential)
        #expect(answer.1 != nil)
        #expect(report.contains("TLS https://100.87.42.19:8737"))
        #expect(report.contains("accepted — pinned key matched"))
        #expect(report.contains(PinnedServerTrustCertificate.fingerprint.rawValue) == false)
        #expect(report.contains(Data(PinnedServerTrustCertificate.der).base64EncodedString()) == false)
        #expect(report.contains("private-user") == false)
        #expect(report.contains("private-password") == false)
        #expect(report.contains("private-bearer-token") == false)
    }

    @Test
    func `given a different saved pin when the session refuses the certificate then copied logs explain the safe mismatch decision`() async throws {
        // given
        let expectedFingerprint = SpkiFingerprint(rawValue: "I5uJIP2xbKC5fDV8f2rN/QyE6RnEDh4HxjReWb18jXQ=")
        let scenario = Scenario(
            pinned: expectedFingerprint,
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )
        let certificate = try #require(
            SecCertificateCreateWithData(nil, Data(PinnedServerTrustCertificate.der) as CFData)
        )
        var trust: SecTrust?
        #expect(SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust) == errSecSuccess)
        let serverTrust: SecTrust = try #require(trust)
        let challenge = URLAuthenticationChallenge(
            protectionSpace: FakeUrlProtectionSpace(host: "100.87.42.19", port: 8737, trust: serverTrust),
            proposedCredential: URLCredential(user: "private-user", password: "private-password", persistence: .none),
            previousFailureCount: 0,
            failureResponse: nil,
            error: NSError(
                domain: "NSURLErrorDomain",
                code: -1200,
                userInfo: [NSLocalizedDescriptionKey: "Bearer private-bearer-token"]
            ),
            sender: FakeUrlAuthenticationChallengeSender()
        )

        // when
        let answer = await withCheckedContinuation { continuation in
            scenario.sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
                continuation.resume(returning: (disposition, credential))
            }
        }
        let report = await scenario.logs.report()

        // then
        #expect(answer.0 == .cancelAuthenticationChallenge)
        #expect(answer.1 == nil)
        #expect(report.contains("TLS https://100.87.42.19:8737"))
        #expect(report.contains("refused — pinned key mismatch"))
        #expect(report.contains(expectedFingerprint.rawValue) == false)
        #expect(report.contains(PinnedServerTrustCertificate.fingerprint.rawValue) == false)
        #expect(report.contains(Data(PinnedServerTrustCertificate.der).base64EncodedString()) == false)
        #expect(report.contains("private-user") == false)
        #expect(report.contains("private-password") == false)
        #expect(report.contains("private-bearer-token") == false)
    }

    @Test
    func `given a server trust challenge carrying no trust when the session refuses it then copied logs explain the unavailable trust`() async throws {
        // given
        let scenario = Scenario(
            pinned: PinnedServerTrustCertificate.fingerprint,
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )
        let challenge = URLAuthenticationChallenge(
            protectionSpace: FakeUrlProtectionSpace(host: "100.87.42.19", port: 8737, trust: nil),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: FakeUrlAuthenticationChallengeSender()
        )

        // when
        let answer = await withCheckedContinuation { continuation in
            scenario.sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
                continuation.resume(returning: (disposition, credential))
            }
        }
        let report = await scenario.logs.report()

        // then
        #expect(answer.0 == .cancelAuthenticationChallenge)
        #expect(answer.1 == nil)
        #expect(report.contains("TLS https://100.87.42.19:8737"))
        #expect(report.contains("refused — server trust unavailable"))
    }

    @Test
    func `given an RSA leaf when the session refuses its unusable public key then copied logs distinguish it from a pin mismatch`() async throws {
        // given
        let scenario = Scenario(
            pinned: PinnedServerTrustCertificate.fingerprint,
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )
        // A real public certificate generated with openssl req -x509 -newkey rsa:2048 -nodes
        // -keyout /dev/null; no private key is retained. RSA exports but is not Granita's P-256.
        let der = try #require(Data(base64Encoded: """
            MIIDIzCCAgugAwIBAgIUWEjiu/yHNGxxH1TRWwdCIDbUnrMwDQYJKoZIhvcNAQEL
            BQAwITEfMB0GA1UEAwwWZ3Jhbml0YS1yc2EtdGVzdC5sb2NhbDAeFw0yNjA5MTIx
            MDQyNDdaFw0zNjA5MTIxMDQyNDdaMCExHzAdBgNVBAMMFmdyYW5pdGEtcnNhLXRl
            c3QubG9jYWwwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDd0Z3WdAV8
            iL0K+FACAGXpLrcA9oWG97JxeDe5K17Cl7cFUmkDVmH80zSP0iWL9y3Rh1z8MIdS
            GqXf710/ZPHg4C4jFivXQrlBO6O+GpLOTzzdh/Yb83rU1DyH48cu2FOqtNXB8Hag
            BeW4GHliCKJJ212UBzkKIdOYYcKpcSv+wrKA4nrc2fOIesVJ0nuIG9A3HbmQWFdx
            Ua3ULK2p9QOqxjpcseCckbXvo9Y9xbGYQLYo8PRfYCVSyw6ky0NTeKo2noxUP1PJ
            AsfR6zNhQtCNilCE93Jbq4TxrOgwkBYdeu0BHOHGOmvaXfHRaCkOhkY8rhLDX2La
            Hj20k86KDJcRAgMBAAGjUzBRMB0GA1UdDgQWBBTVBBh8yjH0OJX84BruUIQFIIt6
            CDAfBgNVHSMEGDAWgBTVBBh8yjH0OJX84BruUIQFIIt6CDAPBgNVHRMBAf8EBTAD
            AQH/MA0GCSqGSIb3DQEBCwUAA4IBAQCMrPDI3JZDenZzxC7Pf45q/NApSFsNrsux
            cSmaU1+FYZzJpLQJXIEkKgC5r4Im0mA+vy/7+loe43Mnp5wiC9IuP6v/Wv2dGG/Z
            Lvl/DF6P5cuEjRPn6nKfJoFol1WS6MM1caT92d0XGvwUAS0It9bZqVj8kntmyQAD
            B+4rrGjr/X97QHRkU4tkMqS4ByYDejAjG6HArFcxS0ok2Ip7ITFazet3p7pmJypd
            MXSmcYTKpYEqJx3FCSDtnHINp92d8EP2f+UNUeP2zu99dRSFsZW3ZVq/uoCvMPSC
            6pQYvik+jpDJqXzlki02tJfAX0neMZzoRujpa1dY6iVpNbFOVYdp
            """, options: .ignoreUnknownCharacters))
        let certificate = try #require(SecCertificateCreateWithData(nil, der as CFData))
        let key = try #require(SecCertificateCopyKey(certificate))
        #expect(SecKeyCopyExternalRepresentation(key, nil) != nil)
        var trust: SecTrust?
        #expect(SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust) == errSecSuccess)
        let serverTrust: SecTrust = try #require(trust)
        let challenge = URLAuthenticationChallenge(
            protectionSpace: FakeUrlProtectionSpace(host: "100.87.42.19", port: 8737, trust: serverTrust),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: FakeUrlAuthenticationChallengeSender()
        )

        // when
        let answer = await withCheckedContinuation { continuation in
            scenario.sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
                continuation.resume(returning: (disposition, credential))
            }
        }
        let report = await scenario.logs.report()

        // then
        #expect(answer.0 == .cancelAuthenticationChallenge)
        #expect(answer.1 == nil)
        #expect(report.contains("TLS https://100.87.42.19:8737"))
        #expect(report.contains("refused — public key unavailable"))
        #expect(report.contains("pinned key mismatch") == false)
        #expect(report.contains(PinnedServerTrustCertificate.fingerprint.rawValue) == false)
        #expect(report.contains(der.base64EncodedString()) == false)
    }

    @Test
    func `given an HTTP Basic challenge when the session delegates its handling then copied logs contain no TLS decision`() async throws {
        // given
        let scenario = Scenario(
            pinned: PinnedServerTrustCertificate.fingerprint,
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )
        let challenge = URLAuthenticationChallenge(
            protectionSpace: FakeUrlProtectionSpace(
                host: "100.87.42.19",
                port: 8737,
                trust: nil,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: FakeUrlAuthenticationChallengeSender()
        )

        // when
        let answer = await withCheckedContinuation { continuation in
            scenario.sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
                continuation.resume(returning: (disposition, credential))
            }
        }
        let report = await scenario.logs.report()

        // then
        #expect(answer.0 == .performDefaultHandling)
        #expect(answer.1 == nil)
        #expect(report.contains("No connection events recorded"))
        #expect(report.contains("TLS https://100.87.42.19:8737") == false)
    }

    @Test
    func `given a certificate with an unsupported key algorithm when its challenge is refused then copied logs explain the unavailable key`() async throws {
        // given
        let scenario = Scenario(
            pinned: PinnedServerTrustCertificate.fingerprint,
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )
        var der = Data(PinnedServerTrustCertificate.der)
        // The certificate still parses, but an unknown SPKI algorithm cannot yield a public key.
        let algorithm = try #require(der.range(of: Data([
            0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01
        ])))
        der.replaceSubrange(algorithm, with: Data([0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x7f]))
        let certificate = try #require(SecCertificateCreateWithData(nil, der as CFData))
        #expect(SecCertificateCopyKey(certificate) == nil)
        var trust: SecTrust?
        #expect(SecTrustCreateWithCertificates(certificate, SecPolicyCreateBasicX509(), &trust) == errSecSuccess)
        let serverTrust: SecTrust = try #require(trust)
        let challenge = URLAuthenticationChallenge(
            protectionSpace: FakeUrlProtectionSpace(host: "100.87.42.19", port: 8737, trust: serverTrust),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: FakeUrlAuthenticationChallengeSender()
        )

        // when
        let answer = await withCheckedContinuation { continuation in
            scenario.sut.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
                continuation.resume(returning: (disposition, credential))
            }
        }
        let report = await scenario.logs.report()

        // then
        #expect(answer.0 == .cancelAuthenticationChallenge)
        #expect(answer.1 == nil)
        #expect(report.contains("TLS https://100.87.42.19:8737"))
        #expect(report.contains("refused — public key unavailable"))
        #expect(report.contains(der.base64EncodedString()) == false)
    }

    private struct Scenario {

        let logs: ConnectionLogs
        let sut: PinnedServerTrust

        init(pinned: SpkiFingerprint, timestamp: Date) {
            logs = ConnectionLogs(
                context: ConnectionLogContext(
                    appVersion: "0.9.1", build: "241", systemVersion: "iOS 26.0", deviceModel: "iPhone"
                ),
                capacity: 8,
                now: { timestamp }
            )
            sut = PinnedServerTrust(pinnedTo: pinned, logs: logs)
        }
    }
}
