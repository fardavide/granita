import Foundation

@testable import ClientConnectionData

actor FakeSessionRequests: SessionRequests {
    private(set) var requests: [URLRequest] = []

    private let answer: Result<(Data, URLResponse), NSError>
    private let eventLines: [String]

    init(answer: Result<(Data, URLResponse), NSError>, eventLines: [String] = []) {
        self.answer = answer
        self.eventLines = eventLines
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try answer.get()
    }

    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse) {
        requests.append(request)
        let (_, response) = try answer.get()
        return (AsyncThrowingStream { continuation in
            for line in eventLines { continuation.yield(line) }
            continuation.finish()
        }, response)
    }
}
