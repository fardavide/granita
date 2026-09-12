import Foundation

/// The system request boundary; tests can fail it without requiring a reachable Mac.
protocol SessionRequests: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct UrlSessionRequests: SessionRequests {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
