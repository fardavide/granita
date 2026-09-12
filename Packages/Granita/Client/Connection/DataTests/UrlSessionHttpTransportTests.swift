import Foundation
import Testing

import ClientConnectionDomain

@testable import ClientConnectionData

@Suite("URL session transport diagnostics")
struct UrlSessionHttpTransportTests {

    @Test
    func `given a non HTTPS URL when an authenticated request is sent then it is refused before reaching the session`() async throws {
        // given
        let url = try #require(URL(string: "http://100.81.42.98:8737/v1/worktrees"))
        let scenario = Scenario(
            answer: .success((
                Data("unexpected insecure response".utf8),
                try #require(HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                ))
            )),
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            try await scenario.sut.send(HttpRequest(
                method: .get,
                url: url,
                headers: ["Authorization": "Bearer bearer-secret"],
                body: nil
            ))
        }
        let invocationCount = await scenario.session.requests.count

        // then
        #expect(invocationCount == 0)
        guard case .requestNotBuildable = failure else {
            Issue.record("A non HTTPS request must be refused as a request that cannot be built")
            return
        }
    }

    @Test
    func `given a TLS failure when an authenticated request is sent then safe transport diagnostics reach the session logs`() async throws {
        // given
        let scenario = Scenario(
            answer: .failure(NSError(
                domain: "NSURLErrorDomain",
                code: -1200,
                userInfo: [
                    NSLocalizedDescriptionKey: "raw-description-secret",
                    NSUnderlyingErrorKey: NSError(
                        domain: "kCFErrorDomainCFNetwork",
                        code: -9824,
                        userInfo: [NSLocalizedDescriptionKey: "underlying-description-secret"]
                    )
                ]
            )),
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )

        // when
        let failure = await #expect(throws: ApiFailure.self) {
            try await scenario.sut.send(HttpRequest(
                method: .get,
                url: try #require(URL(string: "https://100.81.42.98:8737/v1/worktrees")),
                headers: ["Authorization": "Bearer bearer-secret"],
                body: Data("source-secret".utf8)
            ))
        }
        let report = await scenario.logs.report()

        // then
        guard case .unreachable = failure else {
            Issue.record("A TLS transport failure must remain an unreachable API failure")
            return
        }
        #expect(report.contains("GET https://100.81.42.98:8737/v1/worktrees"))
        #expect(report.contains("NSURLErrorDomain (-1200)"))
        #expect(report.contains("kCFErrorDomainCFNetwork (-9824)"))
        #expect(report.contains("bearer-secret") == false)
        #expect(report.contains("source-secret") == false)
        #expect(report.contains("raw-description-secret") == false)
        #expect(report.contains("underlying-description-secret") == false)
    }

    @Test
    func `given an HTTP refusal when pairing is sent then status diagnostics exclude credential and response payloads`() async throws {
        // given
        let url = try #require(URL(string: "https://100.81.42.98:8737/v1/pair?code=pairing-secret"))
        let scenario = Scenario(
            answer: .success((
                Data("source-secret".utf8),
                try #require(HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Set-Cookie": "cookie-secret"]
                ))
            )),
            timestamp: try #require(ISO8601DateFormatter().date(from: "2026-09-12T10:24:35Z"))
        )

        // when
        let response = try await scenario.sut.send(HttpRequest(
            method: .post,
            url: url,
            headers: ["Authorization": "Bearer bearer-secret"],
            body: Data("pairing-body-secret".utf8)
        ))
        let report = await scenario.logs.report()

        // then
        #expect(response.statusCode == 401)
        #expect(response.body == Data("source-secret".utf8))
        #expect(report.contains("POST https://100.81.42.98:8737/v1/pair"))
        #expect(report.contains("HTTP 401"))
        #expect(report.contains("pairing-secret") == false)
        #expect(report.contains("bearer-secret") == false)
        #expect(report.contains("pairing-body-secret") == false)
        #expect(report.contains("source-secret") == false)
        #expect(report.contains("cookie-secret") == false)
    }

    private struct Scenario {
        let sut: UrlSessionHttpTransport
        let logs: ConnectionLogs
        let session: FakeSessionRequests

        init(answer: Result<(Data, URLResponse), NSError>, timestamp: Date) {
            session = FakeSessionRequests(answer: answer)
            logs = ConnectionLogs(
                context: ConnectionLogContext(
                    appVersion: "0.9.1",
                    build: "241",
                    systemVersion: "iOS 26.0",
                    deviceModel: "iPhone"
                ),
                capacity: 8,
                now: { timestamp }
            )
            sut = UrlSessionHttpTransport(
                performing: session,
                trusting: { nil },
                logs: logs
            )
        }
    }
}
