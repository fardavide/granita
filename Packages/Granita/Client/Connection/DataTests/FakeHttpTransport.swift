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

    init(status: Int, json: String) {
        answer = .success(HttpResponse(statusCode: status, body: Data(json.utf8)))
    }

    init(status: Int, body: Data) {
        answer = .success(HttpResponse(statusCode: status, body: body))
    }

    /// A Mac that cannot be reached at all, which is the one failure a transport produces itself.
    init(failing failure: ApiFailure) {
        answer = .failure(failure)
    }

    func send(_ request: HttpRequest) async throws(ApiFailure) -> HttpResponse {
        sent.append(request)
        switch answer {
        case .success(let response): return response
        case .failure(let failure): throw failure
        }
    }
}
