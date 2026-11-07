import Foundation
import Testing

import ClientConnectionDomain
import CoreApiDomain
import CoreDiffDomain
import CorePairingDomain

@testable import ClientConnectionData

@Suite("Native worktree update transport")
struct NativeWorktreeUpdatesTests {
    @Test(.timeLimit(.minutes(1)))
    func `given a native event response when a repository follows updates then the complete typed snapshot arrives`() async throws {
        // given
        let snapshot = WorktreeSnapshot(
            worktrees: [Worktree(
                id: WorktreeID(rawValue: "native-reviewed-worktree"),
                projectId: ProjectID(rawValue: "native-enabled-project"),
                projectName: "Native stream project",
                branch: "feat/native-events",
                isPrimary: false,
                isDetached: false,
                isLocked: true,
                hasUnbornHead: false,
                alias: "café 🍧 review",
                suggestedAlias: "preserve event boundaries",
                displayName: "café 🍧 review",
                directoryName: "native-events-checkout",
                isPinned: true,
                stats: ChangeStats(filesChanged: 3, insertions: 37, deletions: 14),
                lastModified: Date(timeIntervalSince1970: 1_799_999_500),
                revision: "native-content-revision"
            )],
            scannedAt: Date(timeIntervalSince1970: 1_800_000_123)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let event = Data(": heartbeat\r\n\r\nevent: snapshot\r\ndata: ".utf8)
            + (try encoder.encode(snapshot)) + Data("\r\n\r\n".utf8)
        let scenario = try Scenario(event: event)
        let received = AsyncStream<WorktreeUpdate>.makeStream()
        let following = Task {
            for await update in await scenario.sut.updates() { received.continuation.yield(update) }
            received.continuation.finish()
        }
        defer {
            following.cancel()
            scenario.session.invalidateAndCancel()
        }

        // when
        var updates = received.stream.makeAsyncIterator()
        let first = await updates.next()
        following.cancel()
        await following.value

        // then
        #expect(first == .snapshot(snapshot))
    }

    private struct Scenario {
        let sut: HttpGranitaRepository
        let session: URLSession

        init(event: Data) throws {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [FakeUrlProtocol.self]
            configuration.httpAdditionalHeaders = ["X-Fixture-Response-Base64": event.base64EncodedString()]
            session = URLSession(configuration: configuration)
            sut = HttpGranitaRepository(
                macAt: try #require(URL(string: "https://session-fixture.invalid")),
                token: PairingToken(rawValue: "native-paired-device-token"),
                transport: UrlSessionHttpTransport(
                    performing: UrlSessionRequests(session: session),
                    trusting: { SpkiFingerprint(rawValue: "native-fixture-fingerprint") },
                    logs: ConnectionLogs(
                        context: ConnectionLogContext(
                            appVersion: "0.24.0", build: "test", systemVersion: "test", deviceModel: "test"
                        ),
                        capacity: 8,
                        now: { Date(timeIntervalSince1970: 1_800_000_123) }
                    )
                )
            )
        }
    }
}
