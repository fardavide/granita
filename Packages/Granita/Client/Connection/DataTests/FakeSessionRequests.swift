import Foundation

@testable import ClientConnectionData

actor FakeSessionRequests: SessionRequests {
    private(set) var requests: [URLRequest] = []

    private let answer: Result<(Data, URLResponse), NSError>

    init(answer: Result<(Data, URLResponse), NSError>) {
        self.answer = answer
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try answer.get()
    }
}
