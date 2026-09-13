import Foundation
import Testing

@testable import ClientWorktreesDomain

@Suite("Worktree read timing")
struct WorktreeReadTimingTests {

    @Test(arguments: [
        (WorktreeReadTiming.notStarted, Date(timeIntervalSince1970: 1_800_000_100), 0.0),
        (.running(started: Date(timeIntervalSince1970: 1_800_000_000)), Date(timeIntervalSince1970: 1_800_000_042), 42.0),
        (.running(started: Date(timeIntervalSince1970: 1_800_000_100)), Date(timeIntervalSince1970: 1_800_000_042), 0.0),
        (.finished(started: Date(timeIntervalSince1970: 1_800_000_000), ended: Date(timeIntervalSince1970: 1_800_000_042)), Date(timeIntervalSince1970: 1_800_001_000), 42.0)
    ])
    func `given a read clock when elapsed time is asked for then finished attempts stop and clock changes never make a negative wait`(
        timing: WorktreeReadTiming,
        now: Date,
        seconds: Double
    ) {
        // given
        let scenario = Scenario(timing: timing)

        // when
        let elapsed = scenario.sut.elapsed(at: now)

        // then
        #expect(elapsed == seconds)
    }

    private struct Scenario {
        let sut: WorktreeReadTiming

        init(timing: WorktreeReadTiming) {
            sut = timing
        }
    }
}
