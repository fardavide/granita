import Foundation

/// The system request boundary; tests can fail it without requiring a reachable Mac.
protocol SessionRequests: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse)
}

extension SessionRequests {
    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse) {
        throw URLError(.unsupportedURL)
    }
}

struct UrlSessionRequests: SessionRequests {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }

    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        let lines = EventLineStream.buffer(bytes.lines, capacity: 256) {
            bytes.task.cancel()
        }
        return (lines, response)
    }
}
