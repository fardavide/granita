import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

import CoreDiffDomain
import ServerApiPresentation

/// The one route that answers with bytes, driven against the real git binary.
///
/// Serialised for the reason every suite here is: these spawn real subprocesses, and a runner
/// running two dozen of them at once times out invocations that would answer instantly alone.
@Suite("Image route", .serialized)
struct ImageRouteTests {

    // MARK: - Both sides of a replaced picture

    @Test
    func `given a committed picture that changed when its old side is asked for then the commit's bytes come back`(
    ) async throws {
        // given — two distinguishable PNG headers, so a route that answered with the wrong side
        // would fail here rather than pass by looking plausible.
        let scenario = try await Scenario(committed: Self.committed, working: Self.working)
        defer { scenario.cleanUp() }

        // when
        let bytes = try await scenario.api.rawBody(scenario.uri(side: "old"))

        // then
        #expect(bytes == Self.committed)
    }

    @Test
    func `given a picture edited in the working tree when its new side is asked for then the disk's bytes come back`(
    ) async throws {
        // given — the working copy is not in the object database at all, so this is the side that
        // proves the read went somewhere other than git.
        let scenario = try await Scenario(committed: Self.committed, working: Self.working)
        defer { scenario.cleanUp() }

        // when
        let bytes = try await scenario.api.rawBody(scenario.uri(side: "new"))

        // then
        #expect(bytes == Self.working)
    }

    @Test
    func `given no side named when a picture is asked for then the working copy is what comes back`(
    ) async throws {
        // given — the reader's subject is what the agent produced, so the default is the new side,
        // which is the same default the lines route takes.
        let scenario = try await Scenario(committed: Self.committed, working: Self.working)
        defer { scenario.cleanUp() }

        // when
        let bytes = try await scenario.api.rawBody(scenario.uri(side: nil))

        // then
        #expect(bytes == Self.working)
    }

    @Test
    func `given a picture when it is asked for then it is served as the type its extension claims`(
    ) async throws {
        // given
        let scenario = try await Scenario(committed: Self.committed, working: Self.working)
        defer { scenario.cleanUp() }

        // when - then
        try await scenario.api.application.test(.router) { client in
            try await client.execute(uri: scenario.uri(side: "new"), method: .get) { response in
                #expect(response.status == .ok)
                #expect(response.headers[.contentType] == "image/png")
            }
        }
    }

    // MARK: - What it refuses

    @Test
    func `given a file that is not a picture when its bytes are asked for then the route refuses`(
    ) async throws {
        // given — the route serves pictures; every other binary has a collapsed bar saying there is
        // nothing behind it, and answering with bytes here would put one behind it.
        let scenario = try await Scenario(
            committed: Self.committed,
            working: Self.working,
            path: "notes.txt"
        )
        defer { scenario.cleanUp() }

        // when - then
        try await scenario.api.application.test(.router) { client in
            try await client.execute(uri: scenario.uri(side: "new"), method: .get) { response in
                #expect(response.status == .badRequest)
                #expect(errorCode(in: response) == "badRequest")
            }
        }
    }

    @Test
    func `given a file this worktree did not change when its picture is asked for then it is gone`(
    ) async throws {
        // given
        let scenario = try await Scenario(committed: Self.committed, working: Self.working)
        defer { scenario.cleanUp() }

        // when - then
        try await scenario.api.application.test(.router) { client in
            let uri = "/v1/worktrees/\(scenario.worktreeId)/files/deadbeef/image?side=new"
            try await client.execute(uri: uri, method: .get) { response in
                #expect(response.status == .gone)
                #expect(errorCode(in: response) == "fileGone")
            }
        }
    }

    @Test
    func `given a picture that has only just arrived when its committed side is asked for then git says so`(
    ) async throws {
        // given — the phone does not ask for a side `ImageSides` says is absent, so reaching this is
        // a client out of step with the Mac; it still has to answer with something a reader can act
        // on rather than with an empty picture.
        let scenario = try await Scenario(committed: nil, working: Self.working)
        defer { scenario.cleanUp() }

        // when - then
        try await scenario.api.application.test(.router) { client in
            try await client.execute(uri: scenario.uri(side: "old"), method: .get) { response in
                #expect(response.status == .internalServerError)
                #expect(errorCode(in: response) == "gitFailure")
            }
        }
    }

    // MARK: - Fixtures

    /// Two valid PNG signatures with different tails, so the two sides can never be confused.
    private static let committed = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0xC0, 0xFF, 0xEE])
    private static let working = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x01, 0x02])

    // MARK: - Scenario

    private struct Scenario {

        let api: ApiScenario
        let worktreeId: String
        let fileId: String

        private let repository: DisposableRepository

        /// - Parameter committed: what the commit holds, or nothing at all for a file that has only
        ///   ever existed in the working tree.
        init(committed: Data?, working: Data, path: String = "Apps/Snapshots/home-light.png") async throws {
            repository = try DisposableRepository()
            if let committed {
                try repository.commit(path, bytes: committed, message: "add a picture")
            }
            try repository.write(path, bytes: working)

            api = try ApiScenario(at: repository.location)
            try await api.enableProject(at: repository.location)

            let worktrees = try await api.get([Worktree].self, "/v1/worktrees")
            let primary = try #require(worktrees.first { $0.isPrimary })
            worktreeId = primary.id.rawValue

            let changes = try await api.get(
                WorktreeChanges.self,
                "/v1/worktrees/\(worktreeId)/changes"
            )
            fileId = try #require(changes.files.first { $0.path == path }).id.rawValue
        }

        func uri(side: String?) -> String {
            let base = "/v1/worktrees/\(worktreeId)/files/\(fileId)/image"
            return side.map { "\(base)?side=\($0)" } ?? base
        }

        func cleanUp() {
            api.cleanUp()
            repository.cleanUp()
        }
    }
}

private func errorCode(in response: TestResponse) -> String? {
    let object = try? JSONSerialization.jsonObject(with: Data(buffer: response.body)) as? [String: Any]
    return (object?["error"] as? [String: Any])?["code"] as? String
}
