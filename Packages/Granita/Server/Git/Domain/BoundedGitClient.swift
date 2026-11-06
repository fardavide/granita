/// Shares one subprocess budget across background scans and interactive readers.
public actor BoundedGitClient: GitClient {

    private let client: any GitClient
    private let limit: Int
    private var active = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    public init(client: any GitClient, limit: Int) {
        self.client = client
        self.limit = max(1, limit)
    }

    public func run(_ command: GitCommand, in location: RepositoryLocation) async throws(GitError) -> GitOutput {
        if active < limit {
            active += 1
        } else {
            await withCheckedContinuation { waiting.append($0) }
        }
        defer {
            if waiting.isEmpty {
                active -= 1
            } else {
                waiting.removeFirst().resume()
            }
        }
        return try await client.run(command, in: location)
    }
}
