import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

import CoreDiffDomain
import ServerApiPresentation
import ServerStoreDomain

/// SPEC §12's acceptance for M2: every endpoint answered correctly against the real git binary,
/// including the rename, conflict and unborn-HEAD cases.
@Suite("Api routes")
struct ApiRoutesTests {

    // MARK: - Before a phone can say who it is

    @Test
    func `given no token when a route is asked then it refuses and names the reason`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }

        // when - then
        try await scenario.application.test(.router) { client in
            try await client.execute(uri: "/v1/projects", method: .get) { response in
                #expect(response.status == .unauthorized)
                #expect(errorCode(in: response) == "unauthorized")
            }
        }
    }

    @Test
    func `given health when asked without a token then it answers anyway`() async throws {
        // given — a phone at the wrong address, or paired to a Mac that has since been updated,
        // has to be able to tell those apart before it can prove anything about itself.
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }

        // when - then
        try await scenario.application.test(.router) { client in
            try await client.execute(uri: "/v1/health", method: .get) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test
    func `given a client speaking a newer contract when it asks then it is told to update the Mac`(
    ) async throws {
        // given — the two apps ship independently, so skew is guaranteed rather than possible.
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }

        // when - then
        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/projects",
                method: .get,
                headers: [.init("X-Granita-Api-Version")!: "99"]
            ) { response in
                #expect(response.status == .upgradeRequired)
                #expect(errorCode(in: response) == "unsupportedApiVersion")
            }
        }
    }

    @Test
    func `given a pairing code when it is redeemed twice then the second attempt is refused`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }
        let issued = await scenario.pairing.issueCode()

        // when - then — a code single-use is what stops a photograph of the QR pairing a second
        // device long after the first one walked away with it.
        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/pair", method: .post, body: pairBody(code: issued.code)
            ) { response in
                #expect(response.status == .ok)
            }
            try await client.execute(
                uri: "/v1/pair", method: .post, body: pairBody(code: issued.code)
            ) { response in
                #expect(response.status == .unauthorized)
                #expect(errorCode(in: response) == "pairingExpired")
            }
        }
    }

    @Test
    func `given a token from pairing when a route is asked then it is served`() async throws {
        // given
        let scenario = try ApiScenario(repository: .main, requiresAuthentication: true)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let issued = await scenario.pairing.issueCode()

        // when - then
        try await scenario.application.test(.router) { client in
            var token = ""
            try await client.execute(
                uri: "/v1/pair", method: .post, body: pairBody(code: issued.code)
            ) { response in
                token = try decoded(PairedToken.self, from: response).token
            }
            try await client.execute(
                uri: "/v1/projects",
                method: .get,
                headers: [.authorization: "Bearer \(token)"]
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    // MARK: - What there is to read

    @Test
    func `given an enabled project when its worktrees are asked for then each one is described`(
    ) async throws {
        // given — the fixture has the primary checkout plus two linked worktrees, one of them
        // outside the repository root entirely.
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()

        // when
        let worktrees = try await scenario.get([Worktree].self, "/v1/worktrees")

        // then
        #expect(worktrees.count == 3)
        let primary = try #require(worktrees.first { $0.isPrimary })
        #expect(primary.branch == "main")
        #expect(primary.displayName == "main")
        #expect(primary.hasUnbornHead == false)
        #expect(primary.stats.filesChanged > 0)
    }

    @Test
    func `given a worktree when it is listed then its timestamp is an ISO 8601 string`() async throws {
        // given — the date format is part of the contract and is currently whatever the HTTP
        // framework's encoder defaults to. Asserted here rather than assumed, so a framework
        // upgrade that switches to seconds-since-epoch is a red test rather than a phone that
        // silently shows every worktree as modified in 1970.
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()

        // when
        let raw = try await scenario.rawBody("/v1/worktrees")

        // then
        let worktrees = try #require(try JSONSerialization.jsonObject(with: raw) as? [[String: Any]])
        let lastModified = try #require(worktrees.first?["lastModified"] as? String)
        #expect(ISO8601DateFormatter().date(from: lastModified) != nil)
    }

    @Test
    func `given a repository with no commits when its changes are asked for then it is fully added`(
    ) async throws {
        // given — `git diff HEAD` exits 128 here while every other command carries on, so this is
        // the case that turns a fresh project into an error if the empty tree is not substituted.
        let scenario = try ApiScenario(repository: .unborn)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()

        let worktrees = try await scenario.get([Worktree].self, "/v1/worktrees")
        let worktree = try #require(worktrees.first)

        // when
        let changes = try await scenario.get(
            ChangesBody.self,
            "/v1/worktrees/\(worktree.id.rawValue)/changes"
        )

        // then
        #expect(worktree.hasUnbornHead)
        #expect(changes.files.contains { $0.path == "new.txt" })
    }

    @Test
    func `given a rename when the changes are asked for then the stats sit on the file that moved`(
    ) async throws {
        // given
        let scenario = try ApiScenario(repository: .renames)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let worktree = try #require(try await scenario.get([Worktree].self, "/v1/worktrees").first)

        // when
        let changes = try await scenario.get(
            ChangesBody.self,
            "/v1/worktrees/\(worktree.id.rawValue)/changes"
        )

        // then — the two commands this is assembled from report a rename's paths in opposite
        // orders, and getting it wrong shows a file that is not there with stats that belong to
        // one that is.
        let renamed = try #require(changes.files.first { $0.status == .renamed })
        #expect(renamed.path == "new.txt")
        #expect(renamed.oldPath == "old.txt")
        #expect(renamed.stats.insertions == 1)
    }

    @Test
    func `given a conflicted merge when the changes are asked for then the path says so`() async throws {
        // given
        let scenario = try ApiScenario(repository: .conflicted)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let worktree = try #require(try await scenario.get([Worktree].self, "/v1/worktrees").first)

        // when
        let changes = try await scenario.get(
            ChangesBody.self,
            "/v1/worktrees/\(worktree.id.rawValue)/changes"
        )

        // then
        #expect(changes.files.contains { $0.path == "conflict.txt" && $0.status == .conflicted })
    }

    @Test
    func `given a changed file when its diff is asked for then the hunks arrive parsed`() async throws {
        // given
        let scenario = try ApiScenario(repository: .renames)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let worktree = try #require(try await scenario.get([Worktree].self, "/v1/worktrees").first)
        let changes = try await scenario.get(
            ChangesBody.self,
            "/v1/worktrees/\(worktree.id.rawValue)/changes"
        )
        let file = try #require(changes.files.first { $0.path == "plain.txt" })

        // when
        let diff = try await scenario.get(
            FileDiff.self,
            "/v1/worktrees/\(worktree.id.rawValue)/files/\(file.id.rawValue)/diff?context=3"
        )

        // then
        #expect(diff.hunks.isEmpty == false)
        #expect(diff.hunks.flatMap(\.lines).contains { $0.kind == .addition })
    }

    @Test
    func `given more files than one request may carry when diffs are asked for then it is refused`(
    ) async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let worktree = try #require(try await scenario.get([Worktree].self, "/v1/worktrees").first)
        let ids = (0..<21).map { "id\($0)" }.joined(separator: ",")

        // when - then — batching exists so that opening a forty-file worktree is not forty-one
        // round trips; it is not licence to spawn forty git processes from one request.
        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/worktrees/\(worktree.id.rawValue)/diffs?fileIDs=\(ids)",
                method: .get
            ) { response in
                #expect(response.status == .contentTooLarge)
                #expect(errorCode(in: response) == "tooLarge")
            }
        }
    }

    // MARK: - What a reader changes

    @Test
    func `given an alias then a pin when set through the api then neither clears the other`(
    ) async throws {
        // given
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let worktree = try #require(try await scenario.get([Worktree].self, "/v1/worktrees").first)
        let uri = "/v1/worktrees/\(worktree.id.rawValue)"

        // when
        try await scenario.application.test(.router) { client in
            try await client.execute(uri: uri, method: .patch, body: json(#"{"alias":"the parser"}"#)) { _ in }
            try await client.execute(uri: uri, method: .patch, body: json(#"{"isPinned":true}"#)) { response in
                let updated = try decoded(Worktree.self, from: response)
                // An absent key means unchanged, which is what makes a partial update partial.
                #expect(updated.alias == "the parser")
                #expect(updated.isPinned)
                #expect(updated.displayName == "the parser")
            }

            // then — an explicit null is a different request from an absent key, and `Codable`
            // decodes both to nil unless presence is read separately.
            try await client.execute(uri: uri, method: .patch, body: json(#"{"alias":null}"#)) { response in
                let updated = try decoded(Worktree.self, from: response)
                #expect(updated.alias == nil)
                #expect(updated.isPinned)
            }
        }
    }

    @Test
    func `given a file marked viewed at content it no longer has when marked then it is refused`(
    ) async throws {
        // given
        let scenario = try ApiScenario(repository: .renames)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()
        let worktree = try #require(try await scenario.get([Worktree].self, "/v1/worktrees").first)
        let changes = try await scenario.get(
            ChangesBody.self,
            "/v1/worktrees/\(worktree.id.rawValue)/changes"
        )
        let file = try #require(changes.files.first)
        let uri = "/v1/worktrees/\(worktree.id.rawValue)/files/\(file.id.rawValue)/viewed"

        // when - then
        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: uri,
                method: .post,
                body: json(#"{"viewed":true,"contentHash":"\#(file.contentHash)"}"#)
            ) { response in
                #expect(response.status == .noContent)
            }
            try await client.execute(
                uri: uri,
                method: .post,
                body: json(#"{"viewed":true,"contentHash":"something else entirely"}"#)
            ) { response in
                // Marking a version nobody read as read is the one way this can actively mislead.
                #expect(response.status == .conflict)
                #expect(errorCode(in: response) == "staleContentHash")
            }
        }
    }

    @Test
    func `given a worktree identifier no enabled project has when asked then it is gone rather than found`(
    ) async throws {
        // given — the only paths that exist are the ones a person added by hand, so an identifier
        // for anything else resolves to nothing rather than to a directory.
        let scenario = try ApiScenario(repository: .main)
        defer { scenario.cleanUp() }
        try await scenario.enableProject()

        // when - then
        try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/worktrees/\(WorktreeID(canonicalPath: "/etc").rawValue)/changes",
                method: .get
            ) { response in
                #expect(response.status == .gone)
                #expect(errorCode(in: response) == "worktreeGone")
            }
        }
    }
}

// MARK: - Reading responses

/// Mirrors of the response bodies, decoded rather than shared, so a route quietly changing shape
/// fails here instead of being re-encoded by the same type that produced it.
private struct ChangesBody: Decodable, Sendable {
    let revision: String
    let stats: ChangeStats
    let files: [FileChange]
    let isTruncated: Bool
}

private struct PairedToken: Decodable, Sendable {
    let token: String
    let deviceId: String
    let serverInstanceId: String
}

private func pairBody(code: String) -> ByteBuffer {
    json(#"{"code":"\#(code)","deviceName":"a phone","platform":"iOS"}"#)
}

private func json(_ text: String) -> ByteBuffer {
    ByteBuffer(string: text)
}

private func decoded<Value: Decodable>(_ type: Value.Type, from response: TestResponse) throws -> Value {
    try wireDecoder().decode(Value.self, from: Data(buffer: response.body))
}

/// Timestamps travel as ISO 8601 strings, which the test asserting the raw shape pins down.
func wireDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}

private func errorCode(in response: TestResponse) -> String? {
    let object = try? JSONSerialization.jsonObject(with: Data(buffer: response.body)) as? [String: Any]
    return (object?["error"] as? [String: Any])?["code"] as? String
}

extension ApiScenario {

    /// A GET whose body is expected, with the whole response surfaced when it is not.
    ///
    /// The value is returned out of the closures rather than assigned into a captured variable:
    /// the test client runs its body concurrently, so a captured `var` is a data race the compiler
    /// refuses rather than a convenience.
    func get<Value: Decodable & Sendable>(_ type: Value.Type, _ uri: String) async throws -> Value {
        try await application.test(.router) { client in
            try await client.execute(uri: uri, method: .get) { response in
                guard response.status == .ok else {
                    throw UnexpectedStatus(status: "\(response.status)", body: String(buffer: response.body))
                }
                return try wireDecoder().decode(Value.self, from: Data(buffer: response.body))
            }
        }
    }

    func rawBody(_ uri: String) async throws -> Data {
        try await application.test(.router) { client in
            try await client.execute(uri: uri, method: .get) { response in
                Data(buffer: response.body)
            }
        }
    }
}

struct UnexpectedStatus: Error, CustomStringConvertible {
    let status: String
    let body: String
    var description: String { "\(status): \(body)" }
}
