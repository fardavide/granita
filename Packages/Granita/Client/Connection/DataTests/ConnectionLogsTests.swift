import Foundation
import Testing

import ClientConnectionData

@Suite("Connection logs")
struct ConnectionLogsTests {

    @Test
    func `given a failed request with credential-bearing URL when logs are copied then useful diagnostics exclude secrets`() async throws {
        // given
        let scenario = Scenario(
            context: ConnectionLogContext(
                appVersion: "0.9.1",
                build: "241",
                systemVersion: "iOS 26.0",
                deviceModel: "iPhone"
            ),
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )

        // when
        await scenario.sut.record(.requestFailed(
            method: .get,
            url: try #require(URL(string:
                "https://private-user:private-password@100.87.42.19:8737/v1/health"
                    + "?pairingCode=private-pairing-code&token=private-bearer-token#private-fragment"
            )),
            errors: [
                ConnectionLogError(domain: "NSURLErrorDomain", code: -1200),
                ConnectionLogError(domain: "kCFErrorDomainCFNetwork", code: -9824)
            ]
        ))
        let report = await scenario.sut.report()

        // then
        #expect(report.contains("0.9.1"))
        #expect(report.contains("241"))
        #expect(report.contains("iOS 26.0"))
        #expect(report.contains("iPhone"))
        #expect(report.contains("2026-09-12T10:24:35Z"))
        #expect(report.contains("GET https://100.87.42.19:8737/v1/health"))
        #expect(report.contains("NSURLErrorDomain (-1200)"))
        #expect(report.contains("kCFErrorDomainCFNetwork (-9824)"))
        #expect(report.contains("private-user") == false)
        #expect(report.contains("private-password") == false)
        #expect(report.contains("pairingCode") == false)
        #expect(report.contains("private-pairing-code") == false)
        #expect(report.contains("token") == false)
        #expect(report.contains("private-bearer-token") == false)
        #expect(report.contains("private-fragment") == false)
    }

    @Test
    func `given logs with capacity two when three requests fail then the newest two remain in recording order`() async throws {
        // given
        let scenario = Scenario(
            context: ConnectionLogContext(
                appVersion: "0.9.1",
                build: "241",
                systemVersion: "iOS 26.0",
                deviceModel: "iPhone"
            ),
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z")),
            capacity: 2
        )

        // when
        for path in ["/v1/health", "/v1/worktrees", "/v1/projects"] {
            await scenario.sut.record(.requestFailed(
                method: .get,
                url: try #require(URL(string: "https://100.87.42.19:8737" + path)),
                errors: [ConnectionLogError(domain: "NSURLErrorDomain", code: -1200)]
            ))
        }
        let report = await scenario.sut.report()

        // then
        #expect(report.contains("/v1/health") == false)
        let worktrees = try #require(report.range(of: "/v1/worktrees"))
        let projects = try #require(report.range(of: "/v1/projects"))
        #expect(worktrees.lowerBound < projects.lowerBound)
    }

    @Test
    func `given nested system errors carrying secrets when diagnostic codes are extracted then only domains and codes survive`() {
        // given
        let failure = NSError(
            domain: "NSURLErrorDomain",
            code: -1200,
            userInfo: [
                NSLocalizedDescriptionKey: "Bearer private-bearer-token could not connect",
                "failedUrl": "https://100.87.42.19:8737/v1/health?pairingCode=private-pairing-code",
                NSUnderlyingErrorKey: NSError(
                    domain: "kCFErrorDomainCFNetwork",
                    code: -9824,
                    userInfo: [
                        NSLocalizedDescriptionKey: "TLS failed with private-password",
                        "privateBody": "private-source-code"
                    ]
                )
            ]
        )

        // when
        let errors = ConnectionLogError.chain(for: failure)

        // then
        #expect(errors.map(\.domain) == ["NSURLErrorDomain", "kCFErrorDomainCFNetwork"])
        #expect(errors.map(\.code) == [-1200, -9824])
    }

    @Test
    func `given no connection events in this app session when logs are copied then the report explains its scope and empty state`() async throws {
        // given
        let scenario = Scenario(
            context: ConnectionLogContext(
                appVersion: "0.9.1",
                build: "241",
                systemVersion: "iOS 26.0",
                deviceModel: "iPhone"
            ),
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )

        // when
        let report = await scenario.sut.report()

        // then
        #expect(report.contains("Current app session"))
        #expect(report.contains("Collected: 2026-09-12T10:24:35Z"))
        #expect(report.contains("No connection events recorded"))
    }

    private struct Scenario {
        let sut: ConnectionLogs

        init(context: ConnectionLogContext, timestamp: Date, capacity: Int = 8) {
            sut = ConnectionLogs(context: context, capacity: capacity, now: { timestamp })
        }
    }
}
