import Foundation

import ClientConnectionData
import ClientConnectionDomain
import CorePairingDomain

/// Answers every request the same way, and remembers what it was asked.
///
/// One answer rather than a script of them: every route here is a single request, and a fake that
/// replays a queue invites tests that depend on call order without ever saying so.
actor FakeHttpTransport: HttpTransport {

    /// What this transport claims to have trusted. `nil` unless a test says otherwise, because
    /// almost none of them are about the handshake — and a fake that invented a fingerprint would
    /// let a pairing test pass while asserting nothing about what got pinned.
    var presented: SpkiFingerprint?

    func present(_ fingerprint: SpkiFingerprint) {
        presented = fingerprint
    }

    func trustedFingerprint() async -> SpkiFingerprint? { presented }

    /// Every request that reached it, so a test can assert the method, the address and the headers
    /// the client sends without a server on the other end.
    private(set) var sent: [HttpRequest] = []

    private let answer: Result<HttpResponse, ApiFailure>
    private var keepsEventsOpen = false
    private var openEvents: [AsyncThrowingStream<String, any Error>.Continuation] = []
    private var legacyWorktrees: LegacyWorktrees = .sameAnswer

    init(status: Int, json: String, keepingEventsOpen: Bool = false) {
        answer = .success(HttpResponse(statusCode: status, body: Data(json.utf8)))
        keepsEventsOpen = keepingEventsOpen
    }

    init(status: Int, body: Data) {
        answer = .success(HttpResponse(statusCode: status, body: body))
    }

    init(legacyWorktrees json: String) {
        answer = .success(HttpResponse(statusCode: 404, body: Data()))
        legacyWorktrees = .body(Data(json.utf8))
    }

    /// A Mac that cannot be reached at all, which is the one failure a transport produces itself.
    init(failing failure: ApiFailure) {
        answer = .failure(failure)
    }

    func send(_ request: HttpRequest) async throws(ApiFailure) -> HttpResponse {
        sent.append(request)
        if request.url.path() == "/v1/worktrees", case .body(let body) = legacyWorktrees {
            return HttpResponse(statusCode: 200, body: body)
        }
        switch answer {
        case .success(let response): return response
        case .failure(let failure): throw failure
        }
    }

    func stream(_ request: HttpRequest) async throws(ApiFailure) -> HttpEventResponse {
        sent.append(request)
        let response = try answer.get()
        let pair = AsyncThrowingStream<String, any Error>.makeStream()
        for line in String(decoding: response.body, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false) {
            pair.continuation.yield(String(line))
        }
        if keepsEventsOpen {
            openEvents.append(pair.continuation)
        } else {
            pair.continuation.finish()
        }
        return HttpEventResponse(statusCode: response.statusCode, lines: pair.stream)
    }

    func finishEvents() {
        for continuation in openEvents { continuation.finish() }
        openEvents = []
    }

    func refuseEvents(with failure: ApiFailure) {
        for continuation in openEvents { continuation.finish(throwing: failure) }
        openEvents = []
    }

    private enum LegacyWorktrees {
        case sameAnswer
        case body(Data)
    }
}
