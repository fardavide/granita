import Foundation
import Testing

import ClientConnectionDomain
import CoreApiDomain
@testable import ClientConnectionData

@Suite("Event line buffering")
struct EventLineStreamTests {
    @Test
    func `given complete event lines fit the buffer when the source finishes then every line arrives in order before completion`() async throws {
        // given
        let lines = ["event: snapshot", "data: complete-inventory", ""]
        let scenario = Scenario(lines: lines, capacity: lines.count)

        // when
        var received: [String] = []
        for try await line in scenario.sut { received.append(line) }

        // then
        #expect(received == lines)
        var completed = scenario.completed.makeAsyncIterator()
        #expect(await completed.next() != nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func `given a snapshot prefix was read when buffered lines overflow then complete queued frames precede a retryable transport failure`() async throws {
        // given
        let scenario = Scenario(lines: [
            "",
            "event: snapshot",
            "data: {\"worktrees\":[],\"scannedAt\":\"1970-01-01T00:33:20Z\"}",
            ""
        ] + Array(repeating: ": heartbeat", count: 257), capacity: 256)
        var decoder = WorktreeEventDecoder()
        _ = try decoder.receive("event: snapshot")
        _ = try decoder.receive("data: {\"worktrees\":[],\"scannedAt\":\"1970-01-01T00:16:40Z\"}")
        var completion = scenario.completed.makeAsyncIterator()
        _ = await completion.next()

        // when
        var snapshots: [WorktreeSnapshot] = []
        var failure: ApiFailure?
        do {
            for try await line in scenario.sut {
                switch try decoder.receive(line) {
                case .none: break
                case .snapshot(let snapshot): snapshots.append(snapshot)
                }
            }
        } catch {
            failure = ApiFailure.forTransport(error)
        }

        // then
        #expect(snapshots == [
            WorktreeSnapshot(worktrees: [], scannedAt: Date(timeIntervalSince1970: 1_000)),
            WorktreeSnapshot(worktrees: [], scannedAt: Date(timeIntervalSince1970: 2_000))
        ])
        guard case .unreachable? = failure else {
            Issue.record("Overflow should reach the reconnect policy as a transport failure; got \(String(describing: failure))")
            return
        }
    }

    private struct Scenario {
        let sut: AsyncThrowingStream<String, any Error>
        let completed: AsyncStream<Void>

        init(lines: [String], capacity: Int) {
            let completion = AsyncStream<Void>.makeStream()
            completed = completion.stream
            let source = AsyncStream<String> { continuation in
                for line in lines { continuation.yield(line) }
                continuation.finish()
            }
            sut = EventLineStream.buffer(source, capacity: capacity) {
                completion.continuation.yield(())
                completion.continuation.finish()
            }
        }
    }
}
