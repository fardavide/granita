import Foundation
import Testing

import ClientConnectionData

struct ServerTrustRedirectTests {

    @Test(arguments: TrustKind.allCases)
    func `given a trust delegate when HTTPS redirects to HTTP then the redirect is refused`(
        kind: TrustKind
    ) async throws {
        // given
        let scenario = Scenario(kind: kind)
        defer { scenario.session.invalidateAndCancel() }
        let originalUrl = try #require(URL(string: "https://100.81.42.98:8737/v1/worktrees"))
        let redirectUrl = try #require(URL(string: "http://100.81.42.98:8737/v1/worktrees"))
        let task = scenario.session.dataTask(with: originalUrl)
        let response = try #require(HTTPURLResponse(
            url: originalUrl,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": redirectUrl.absoluteString]
        ))
        let taskDelegate = try #require(
            scenario.sut as? any URLSessionTaskDelegate,
            "Both trust delegates must handle task redirects"
        )
        try #require(taskDelegate.responds(to: #selector(
            URLSessionTaskDelegate.urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)
        )), "Both trust delegates must implement the native redirect callback")

        // when
        let acceptedRequest = await withCheckedContinuation {
            (continuation: CheckedContinuation<URLRequest?, Never>) in
            taskDelegate.urlSession?(
                scenario.session,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: URLRequest(url: redirectUrl),
                completionHandler: { continuation.resume(returning: $0) }
            )
        }

        // then
        #expect(acceptedRequest == nil)
    }

    enum TrustKind: CaseIterable, Sendable {
        case pinned
        case firstContact
    }

    private struct Scenario {
        let sut: any URLSessionDelegate
        let session: URLSession

        init(kind: TrustKind) {
            switch kind {
            case .pinned:
                sut = PinnedServerTrust(
                    pinnedTo: PinnedServerTrustCertificate.fingerprint,
                    logs: ConnectionLogs(
                        context: ConnectionLogContext(
                            appVersion: "acceptance",
                            build: "fixture",
                            systemVersion: "host",
                            deviceModel: "Mac"
                        ),
                        capacity: 8,
                        now: { Date(timeIntervalSince1970: 0) }
                    )
                )
            case .firstContact:
                sut = FirstContactServerTrust()
            }
            session = URLSession(configuration: .ephemeral, delegate: sut, delegateQueue: nil)
        }
    }
}
