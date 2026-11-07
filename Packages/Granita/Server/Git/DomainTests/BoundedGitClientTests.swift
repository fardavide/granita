import Foundation
import Testing

import ServerGitDomain

@Suite("Bounded git client")
struct BoundedGitClientTests {

    @Test
    func `given concurrent readers when commands run then subprocess concurrency stays within the limit`() async throws {
        // given
        let scenario = Scenario(limit: 2)

        // when
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    _ = try await scenario.sut.run(.headCommit, in: RepositoryLocation(path: "/concurrent-readers"))
                }
            }
            try await group.waitForAll()
        }

        // then
        #expect(await scenario.client.maximumActive <= 2)
        #expect(await scenario.client.received.count == 20)
    }

    private struct Scenario {
        let client: FakeGitClient
        let sut: BoundedGitClient

        init(limit: Int) {
            client = FakeGitClient(
                output: GitOutput(standardOutput: Data("commit-id".utf8), isTruncated: false),
                failure: nil,
                yields: true
            )
            sut = BoundedGitClient(client: client, limit: limit)
        }
    }
}
