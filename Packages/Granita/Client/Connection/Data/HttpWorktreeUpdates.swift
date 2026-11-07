import ClientConnectionDomain

struct HttpWorktreeUpdates: Sendable {
    private let updates: WorktreeUpdates

    init(client: GranitaHttpClient) {
        updates = WorktreeUpdates { receive throws(ApiFailure) in
            do {
                let response = try await client.eventStream()
                var decoder = WorktreeEventDecoder()
                for try await line in response.lines {
                    guard !Task.isCancelled else { throw ApiFailure.cancelled }
                    switch try decoder.receive(line) {
                    case .none: break
                    case .snapshot(let snapshot): await receive(snapshot)
                    }
                }
            } catch {
                throw ApiFailure.forTransport(error)
            }
        }
    }

    func stream() async -> AsyncStream<WorktreeUpdate> {
        await updates.stream()
    }
}
