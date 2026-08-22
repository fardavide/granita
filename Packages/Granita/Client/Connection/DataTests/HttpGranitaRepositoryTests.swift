import Foundation
import Testing

import ClientConnectionData
import ClientConnectionDomain
import CoreApiDomain
import CoreBrandingDomain
import CoreDiffDomain

/// Everything the phone reads once it is paired, and the two rules that hold across all of it: a
/// bearer on every request, and a refusal that arrives as something the phone has a screen for
/// rather than as a number.
@Suite("Http Granita repository")
struct HttpGranitaRepositoryTests {

    // MARK: - What every request carries

    @Test
    func `given a paired phone when it reads anything then it offers its token`() async throws {
        // given
        let scenario = Scenario(status: 200, json: "[]")

        // when
        _ = try await scenario.sut.projects()

        // then
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.headers["Authorization"] == "Bearer 1f0e4d7c6b5a49382736251403f2e1d0")
        #expect(request.headers[Branding.apiVersionHeader] == String(Branding.apiVersion))
    }

    // MARK: - The routes

    @Test
    func `given enabled projects when they are listed then each one arrives whole`() async throws {
        // given
        let scenario = Scenario(status: 200, json: """
            [
              {
                "id": "4a1b2c3d4e5f60718293a4b5c6d7e8f9",
                "name": "Granita",
                "isVisible": true,
                "worktreeCount": 4,
                "dirtyWorktreeCount": 2
              }
            ]
            """)

        // when
        let projects = try await scenario.sut.projects()

        // then
        #expect(projects == [
            Project(
                id: ProjectID(rawValue: "4a1b2c3d4e5f60718293a4b5c6d7e8f9"),
                name: "Granita",
                isVisible: true,
                worktreeCount: 4,
                dirtyWorktreeCount: 2
            )
        ])
        #expect(try #require(await scenario.transport.sent.first).url.path() == "/v1/projects")
    }

    @Test
    func `given every project when worktrees are listed then no project is named`() async throws {
        // given
        let scenario = Scenario(status: 200, json: "[]")

        // when
        _ = try await scenario.sut.worktrees(inProject: nil)

        // then — the parameter is omitted rather than sent empty, because an empty one asks for the
        // worktrees of a project whose identifier is the empty string.
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.url.path() == "/v1/worktrees")
        #expect(request.url.query() == nil)
    }

    @Test
    func `given one project when its worktrees are listed then it is named in the query`() async throws {
        // given
        let scenario = Scenario(status: 200, json: try encoded([aWorktree]))

        // when
        let worktrees = try await scenario.sut.worktrees(
            inProject: ProjectID(rawValue: "4a1b2c3d4e5f60718293a4b5c6d7e8f9")
        )

        // then
        #expect(worktrees == [aWorktree])
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.url.query() == "projectID=4a1b2c3d4e5f60718293a4b5c6d7e8f9")
    }

    @Test
    func `given a new name when a worktree is renamed then the alias travels and the worktree comes back`() async throws {
        // given
        let scenario = Scenario(status: 200, json: try encoded(aWorktree))

        // when
        let updated = try await scenario.sut.update(
            WorktreeID(rawValue: "aaaa1111bbbb2222cccc3333dddd4444"),
            with: WorktreePatch(alias: .set("the bridge slice"), isPinned: nil)
        )

        // then
        #expect(updated == aWorktree)
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.method == .patch)
        #expect(request.url.path() == "/v1/worktrees/aaaa1111bbbb2222cccc3333dddd4444")
        let body = try #require(request.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object.keys.sorted() == ["alias"])
        #expect(object["alias"] as? String == "the bridge slice")
    }

    @Test
    func `given a worktree when its changes are read then the revision and the stats arrive`() async throws {
        // given
        let scenario = Scenario(status: 200, json: """
            {
              "revision": "6f2ad91c",
              "stats": { "filesChanged": 3, "insertions": 41, "deletions": 7 },
              "files": [],
              "isTruncated": false
            }
            """)

        // when
        let changes = try await scenario.sut.changes(
            in: WorktreeID(rawValue: "aaaa1111bbbb2222cccc3333dddd4444")
        )

        // then
        #expect(changes == WorktreeChanges(
            revision: "6f2ad91c",
            stats: ChangeStats(filesChanged: 3, insertions: 41, deletions: 7),
            files: [],
            isTruncated: false
        ))
        #expect(
            try #require(await scenario.transport.sent.first).url.path()
                == "/v1/worktrees/aaaa1111bbbb2222cccc3333dddd4444/changes"
        )
    }

    @Test
    func `given several files when their diffs are prefetched then they are asked for in one request`() async throws {
        // given — opening a forty-file worktree must not be forty-one round trips.
        let scenario = Scenario(status: 200, json: "[]")

        // when
        _ = try await scenario.sut.diffs(
            of: [FileID(rawValue: "1111"), FileID(rawValue: "2222"), FileID(rawValue: "3333")],
            in: WorktreeID(rawValue: "aaaa1111bbbb2222cccc3333dddd4444"),
            contextLines: 5
        )

        // then
        let requests = await scenario.transport.sent
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.url.path() == "/v1/worktrees/aaaa1111bbbb2222cccc3333dddd4444/diffs")
        #expect(request.url.query() == "fileIDs=1111,2222,3333&context=5")
    }

    @Test
    func `given a hunk being expanded when raw lines are read then the side and the window travel`() async throws {
        // given
        let scenario = Scenario(status: 200, json: #"{"lines":["import Foundation",""],"eof":true}"#)

        // when
        let lines = try await scenario.sut.lines(
            of: FileID(rawValue: "9999"),
            in: WorktreeID(rawValue: "aaaa1111bbbb2222cccc3333dddd4444"),
            side: .old,
            start: 12,
            count: 40
        )

        // then
        #expect(lines == FileLines(lines: ["import Foundation", ""], eof: true))
        let request = try #require(await scenario.transport.sent.first)
        #expect(
            request.url.path() == "/v1/worktrees/aaaa1111bbbb2222cccc3333dddd4444/files/9999/lines"
        )
        #expect(request.url.query() == "side=old&start=12&count=40")
    }

    @Test
    func `given a file the reader has read when it is marked then the content it was read at travels`() async throws {
        // given — a mark against anything else is refused, so sending the hash is not optional.
        let scenario = Scenario(status: 204, body: Data())

        // when
        try await scenario.sut.markViewed(
            true,
            file: FileID(rawValue: "9999"),
            contentHash: String(repeating: "c", count: 64),
            in: WorktreeID(rawValue: "aaaa1111bbbb2222cccc3333dddd4444")
        )

        // then
        let request = try #require(await scenario.transport.sent.first)
        #expect(request.method == .post)
        #expect(
            request.url.path() == "/v1/worktrees/aaaa1111bbbb2222cccc3333dddd4444/files/9999/viewed"
        )
        let body = try #require(request.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["viewed"] as? Bool == true)
        #expect(object["contentHash"] as? String == String(repeating: "c", count: 64))
    }

    // MARK: - Refusals, which arrive as codes rather than as numbers

    @Test(arguments: [
        (ApiErrorCode.unauthorized, ApiFailure.unauthorized),
        (.rateLimited, .rateLimited),
        (.projectNotVisible, .projectNotVisible),
        (.worktreeGone, .worktreeGone),
        (.fileGone, .fileGone),
        (.staleContentHash, .staleContentHash),
        (.tooLarge, .tooLarge),
        (.unsupportedApiVersion, .unsupportedApiVersion)
    ])
    func `given a refusal the contract names when reading then it arrives as its own failure`(
        code: ApiErrorCode,
        expected: ApiFailure
    ) async {
        // given
        let scenario = Scenario(
            status: 400,
            json: #"{"error":{"code":"\#(code.rawValue)","message":"no"}}"#
        )

        // when - then — the status is deliberately the same for all of them: the phone branches on
        // the code, so a mapping that read the number would be a mapping that could not tell two
        // refusals apart that the Mac spells differently on purpose.
        await #expect(throws: expected) {
            try await scenario.sut.projects()
        }
    }

    @Test
    func `given git failed on the Mac when reading then its own words reach the phone`() async {
        // given — the reader is three rooms away and cannot re-run anything.
        let scenario = Scenario(status: 500, json: #"""
            {"error":{"code":"gitFailure","message":"git exited 128: fatal: not a git repository"}}
            """#)

        // when - then
        await #expect(
            throws: ApiFailure.gitFailure(message: "git exited 128: fatal: not a git repository")
        ) {
            try await scenario.sut.changes(in: WorktreeID(rawValue: "aaaa1111bbbb2222cccc3333dddd4444"))
        }
    }

    @Test
    func `given the Mac serves an older contract when reading then that is what is reported`() async {
        // given — the Mac app is notarised by hand and the phone ships on every merge, so this is
        // the direction skew goes. Nothing on the phone can work around it.
        let scenario = Scenario(
            status: 426,
            json: #"{"error":{"code":"unsupportedApiVersion","message":"this Mac serves version 1"}}"#
        )

        // when - then
        await #expect(throws: ApiFailure.unsupportedApiVersion) {
            try await scenario.sut.projects()
        }
    }
}

// MARK: -

private struct Scenario {

    let sut: HttpGranitaRepository
    let transport: FakeHttpTransport

    init(status: Int, json: String) {
        transport = FakeHttpTransport(status: status, json: json)
        sut = HttpGranitaRepository(macAt: macAddress, token: token, transport: transport)
    }

    init(status: Int, body: Data) {
        transport = FakeHttpTransport(status: status, body: body)
        sut = HttpGranitaRepository(macAt: macAddress, token: token, transport: transport)
    }
}

/// Where the Mac is. A literal, so the failable initialiser Foundation offers cannot fail here.
private let macAddress = URL(string: "https://davides-macbook-pro.local:59144")!

private let token = PairingToken(rawValue: "1f0e4d7c6b5a49382736251403f2e1d0")

/// A worktree with every field distinct, so a mapper that crossed two of them fails loudly.
private let aWorktree = Worktree(
    id: WorktreeID(rawValue: "aaaa1111bbbb2222cccc3333dddd4444"),
    projectId: ProjectID(rawValue: "4a1b2c3d4e5f60718293a4b5c6d7e8f9"),
    projectName: "Granita",
    branch: "feat/bridge",
    isPrimary: false,
    isDetached: false,
    isLocked: false,
    hasUnbornHead: false,
    alias: "the bridge slice",
    suggestedAlias: "wire the phone to the Mac",
    displayName: "the bridge slice",
    directoryName: "bridge-cse",
    isPinned: true,
    stats: ChangeStats(filesChanged: 9, insertions: 620, deletions: 44),
    lastModified: Date(timeIntervalSince1970: 1_787_000_000),
    revision: "6f2ad91c"
)

/// The Mac's own encoding of a value, as a fixture.
///
/// Hand-writing a worktree's sixteen fields as JSON would be a test of a test writer's patience;
/// the field *names* are already pinned from the other end, by the wire-contract suite over these
/// same types and by the route tests that read the raw body.
private func encoded(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return String(decoding: try encoder.encode(value), as: UTF8.self)
}
