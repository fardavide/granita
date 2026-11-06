import Foundation
import Hummingbird
import Testing

import CoreApiDomain
@testable import ServerApiPresentation

@Suite("Worktree event stream")
struct WorktreeEventStreamTests {

    @Test
    func `given a snapshot when streamed then the client receives an SSE JSON frame`() async throws {
        // given
        let snapshot = WorktreeSnapshot(worktrees: [], scannedAt: Date(timeIntervalSince1970: 1_000))
        let scenario = Scenario(snapshots: [snapshot])

        // when
        try await scenario.sut.write(scenario.writer)

        // then
        let frame = await scenario.writer.frames.first ?? ""
        #expect(frame.contains("event: snapshot\n"))
        #expect(frame.hasSuffix("\n\n"))
        let payload = try #require(frame.split(separator: "\n").first { $0.hasPrefix("data: ") })
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(WorktreeSnapshot.self, from: Data(payload.dropFirst(6).utf8)) == snapshot)
    }

    @Test
    func `given authorization was revoked when a snapshot is ready then no source is streamed`() async {
        // given
        let scenario = Scenario(
            snapshots: [WorktreeSnapshot(worktrees: [], scannedAt: Date(timeIntervalSince1970: 1_000))],
            authorized: false
        )

        // when
        var refused = false
        do {
            try await scenario.sut.write(scenario.writer)
        } catch {
            refused = true
        }

        // then
        #expect(refused)
        #expect(await scenario.writer.frames.isEmpty)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a quiet snapshot source when a heartbeat arrives then the connection receives a comment`() async throws {
        // given
        let snapshots = AsyncStream<WorktreeSnapshot>.makeStream()
        let heartbeats = AsyncStream<Void>.makeStream()
        let writer = FakeEventBodyWriter()
        let body = WorktreeEventStream.body(
            snapshots: snapshots.stream,
            authorized: { true },
            heartbeats: heartbeats.stream
        )
        let writing = Task { try await body.write(writer) }

        // when
        heartbeats.continuation.yield(())
        let frame = await writer.firstFrame()
        snapshots.continuation.finish()
        heartbeats.continuation.finish()
        try await writing.value

        // then
        #expect(frame == ": heartbeat\n\n")
    }

    private struct Scenario {
        let sut: ResponseBody
        let writer: FakeEventBodyWriter

        init(snapshots: [WorktreeSnapshot], authorized: Bool = true) {
            writer = FakeEventBodyWriter()
            sut = WorktreeEventStream.body(
                snapshots: AsyncStream { continuation in
                    for snapshot in snapshots { continuation.yield(snapshot) }
                    continuation.finish()
                },
                authorized: { authorized }
            )
        }
    }
}
