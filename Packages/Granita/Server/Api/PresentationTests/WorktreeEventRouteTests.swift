import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

import CoreApiDomain
import ServerApiDomain
import ServerStoreDomain
import ServerWorktreesDomain

@testable import ServerApiPresentation

@Suite("Worktree event route")
struct WorktreeEventRouteTests {

    @Test(arguments: [true, false])
    func `given an authorized reader when opening events then its prepared snapshot arrives without another scan`(
        requiresAuthentication: Bool
    ) async throws {
        // given
        let token = "paired-reader-event-token"
        let scenario = try await Scenario(token: token, requiresAuthentication: requiresAuthentication)
        defer { scenario.api.cleanUp() }
        let prepared = try await scenario.api.reader.snapshot(inProject: nil, refreshing: false)
        let commands = await scenario.api.git.runs.count

        // when
        let response = try await scenario.application.test(.router) { client in
            try await client.execute(
                uri: "/v1/events", method: .get,
                headers: [.authorization: "Bearer \(token)"]
            )
        }

        // then
        #expect(response.status == .ok)
        #expect(response.headers[.contentType] == "text/event-stream")
        #expect(response.headers[.cacheControl] == "no-store")
        let frame = String(decoding: response.body.readableBytesView, as: UTF8.self)
        #expect(frame.hasPrefix("event: snapshot\n"))
        #expect(frame.hasSuffix("\n\n"))
        let payload = try #require(frame.split(separator: "\n").first { $0.hasPrefix("data: ") })
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(WorktreeSnapshot.self, from: Data(payload.dropFirst(6).utf8))
        #expect(snapshot.worktrees.map(\.id) == prepared.worktrees.map(\.id))
        #expect(snapshot.worktrees.map(\.revision) == prepared.worktrees.map(\.revision))
        #expect(snapshot.worktrees.map(\.stats) == prepared.worktrees.map(\.stats))
        #expect(snapshot.worktrees.map { $0.lastModified.timeIntervalSince1970 }
            == prepared.worktrees.map { floor($0.lastModified.timeIntervalSince1970) })
        #expect(snapshot.scannedAt.timeIntervalSince1970 == floor(prepared.scannedAt.timeIntervalSince1970))
        #expect(await scenario.api.git.runs.count == commands)
    }

    private struct Scenario {
        let api: ApiScenario
        let application: any ApplicationProtocol

        init(token: String, requiresAuthentication: Bool) async throws {
            let api = try ApiScenario(repository: .renames, requiresAuthentication: requiresAuthentication)
            try await api.enableProject()
            try await api.store.add(device: StoredDevice(
                id: "paired-reader", name: "Review phone", platform: "iOS",
                tokenHash: TokenHash.of(token), pairedAt: Date(timeIntervalSince1970: 1_000)
            ))
            self.api = api
            let writer = FakeEventBodyWriter(afterFirstFrame: { await api.registry.stop() })
            let responder = GranitaRouter.build(ApiDependencies(
                reader: api.reader, store: api.store, pairing: api.pairing,
                failedAttempts: FailedAttempts(now: { Date() }),
                connectionLog: api.connectionLog, diagnostics: api.diagnostics,
                serverVersion: "event-route-fixture", wakeAddresses: [], tailnetEndpoint: nil,
                requiresAuthentication: requiresAuthentication
            )).buildResponder()
            let capturing = Router(context: GranitaRequestContext.self)
            // Drain the real route through a writer that ends its source after the first frame,
            // so the router test client can collect a finite response without a timer.
            capturing.get("/v1/events") { request, context -> Response in
                let response = try await responder.respond(to: request, context: context)
                try await response.body.write(writer)
                let frames = await writer.frames.joined()
                return Response(
                    status: response.status, headers: response.headers,
                    body: ResponseBody(byteBuffer: ByteBuffer(string: frames))
                )
            }
            application = Application(router: capturing)
        }
    }
}
