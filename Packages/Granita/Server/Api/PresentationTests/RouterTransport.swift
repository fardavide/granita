import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import NIOCore

import ClientConnectionData
import ClientConnectionDomain

/// The phone's transport, wired to the real router in-process.
///
/// No port, no TLS, no Bonjour: the pinned `URLSession` is the one thing this substitutes for, and
/// it is the one thing that is not about the contract. Everything else on the way — the path, the
/// query, the headers, the body, the status and the bytes back — is exactly what the client builds
/// and exactly what the routes read.
struct RouterTransport: HttpTransport {

    let perform: @Sendable (HttpRequest) async throws -> HttpResponse

    func send(_ request: HttpRequest) async throws(ApiFailure) -> HttpResponse {
        do {
            return try await perform(request)
        } catch {
            throw .unreachable(diagnostic: "\(error)")
        }
    }
}

extension RouterTransport {

    /// Drives one of Hummingbird's in-process test clients.
    static func over(_ client: some TestClientProtocol) -> RouterTransport {
        RouterTransport { request in
            var headers = HTTPFields()
            for (name, value) in request.headers {
                guard let field = HTTPField.Name(name) else { continue }
                headers[field] = value
            }
            let query = request.url.query().map { "?\($0)" } ?? ""
            return try await client.execute(
                uri: request.url.path() + query,
                method: method(of: request),
                headers: headers,
                body: request.body.map { ByteBuffer(data: $0) }
            ) { response in
                HttpResponse(statusCode: Int(response.status.code), body: Data(buffer: response.body))
            }
        }
    }

    private static func method(of request: HttpRequest) -> HTTPRequest.Method {
        switch request.method {
        case .get: .get
        case .post: .post
        case .patch: .patch
        }
    }
}
