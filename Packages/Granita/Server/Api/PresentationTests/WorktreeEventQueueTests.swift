import Foundation
import Testing

import CoreApiDomain
@testable import ServerApiPresentation

@Suite("Worktree event backpressure")
struct WorktreeEventQueueTests {

    @Test
    func `given a slow client when the event buffer overflows then the bounded stream ends for reconciliation`() async {
        // given
        let scenario = Scenario(capacity: 2)
        let first = WorktreeSnapshot(worktrees: [], scannedAt: Date(timeIntervalSince1970: 100))
        let second = WorktreeSnapshot(worktrees: [], scannedAt: Date(timeIntervalSince1970: 200))

        // when
        #expect(scenario.sut.send(.snapshot(first)))
        #expect(scenario.sut.send(.heartbeat))
        #expect(scenario.sut.send(.snapshot(second)) == false)
        var frames: [WorktreeEventQueue.Frame] = []
        for await frame in scenario.sut.stream { frames.append(frame) }

        // then
        #expect(frames == [.heartbeat, .snapshot(second)])
        #expect(scenario.sut.send(.heartbeat) == false)
    }

    private struct Scenario {
        let sut: WorktreeEventQueue

        init(capacity: Int) {
            sut = WorktreeEventQueue(capacity: capacity)
        }
    }
}
