import Foundation
import Testing

import CoreDiffDomain
@testable import ServerWorktreesDomain

@Suite("Worktree observation scheduling")
struct WorktreeObservationScheduleTests {
    @Test
    func `given continuous edits when the coalescing period ends then the pending worktree refreshes`() {
        // given
        var scenario = Scenario()
        let worktree = WorktreeID(canonicalPath: "/project/.claude/worktrees/agent")
        for elapsed in [0, 100, 200, 300] {
            scenario.sut.invalidate(.refresh([worktree]), at: .milliseconds(elapsed))
        }

        // when
        let early = scenario.sut.takeDue(at: .milliseconds(399))
        let due = scenario.sut.takeDue(at: .milliseconds(400))

        // then
        #expect(early == .ignore)
        #expect(due == .refresh([worktree]))
    }

    @Test
    func `given a recent refresh when another edit arrives then the next scan waits for the rate limit`() {
        // given
        var scenario = Scenario()
        let worktree = WorktreeID(canonicalPath: "/project/.claude/worktrees/agent")
        scenario.sut.invalidate(.refresh([worktree]), at: .zero)
        _ = scenario.sut.takeDue(at: .milliseconds(400))
        scenario.sut.didFinishRefresh(in: [worktree])
        scenario.sut.invalidate(.refresh([worktree]), at: .milliseconds(500))

        // when
        let early = scenario.sut.takeDue(at: .milliseconds(900))
        let due = scenario.sut.takeDue(at: .milliseconds(2_400))

        // then
        #expect(early == .ignore)
        #expect(due == .refresh([worktree]))
    }

    @Test
    func `given pending file events when events are lost then a coalesced reconciliation supersedes them`() {
        // given
        var scenario = Scenario()
        scenario.sut.invalidate(.refresh([WorktreeID(canonicalPath: "/project")]), at: .zero)

        // when
        scenario.sut.invalidate(.reconcile, at: .milliseconds(100))
        let early = scenario.sut.takeDue(at: .milliseconds(499))
        let due = scenario.sut.takeDue(at: .milliseconds(500))
        let redundant = scenario.sut.takeDue(at: .seconds(3))

        // then
        #expect(early == .ignore)
        #expect(due == .reconcile)
        #expect(redundant == .ignore)
    }

    @Test
    func `given a completed reconciliation when another invalidation arrives then every worktree keeps its rate limit`() {
        // given
        var scenario = Scenario()
        scenario.sut.invalidate(.reconcile, at: .zero)
        _ = scenario.sut.takeDue(at: .milliseconds(400))
        scenario.sut.didFinishReconciliation()

        // when
        scenario.sut.invalidate(.refresh([WorktreeID(canonicalPath: "/project")]), at: .milliseconds(500))
        let early = scenario.sut.takeDue(at: .milliseconds(900))
        let due = scenario.sut.takeDue(at: .milliseconds(2_400))

        // then
        #expect(early == .ignore)
        #expect(due == .refresh([WorktreeID(canonicalPath: "/project")]))
    }

    @Test(arguments: [
        WorktreeObservationReaction.refresh([WorktreeID(canonicalPath: "/project")]),
        .reconcile
    ])
    func `given a recent scan when inventory is invalidated then reconciliation waits for the rate limit`(
        _ initial: WorktreeObservationReaction
    ) {
        // given
        var scenario = Scenario()
        scenario.sut.invalidate(initial, at: .zero)
        _ = scenario.sut.takeDue(at: .milliseconds(400))
        if case .refresh(let worktrees) = initial { scenario.sut.didFinishRefresh(in: worktrees) }
        if case .reconcile = initial { scenario.sut.didFinishReconciliation() }

        // when
        scenario.sut.invalidate(.reconcile, at: .milliseconds(500))
        let early = scenario.sut.takeDue(at: .milliseconds(900))
        let due = scenario.sut.takeDue(at: .milliseconds(2_400))

        // then
        #expect(early == .ignore)
        #expect(due == .reconcile)
    }

    @Test
    func `given a scan is still running when more edits arrive then its pending refresh waits for completion`() {
        // given
        var scenario = Scenario()
        let worktrees: Set<WorktreeID> = [WorktreeID(canonicalPath: "/project")]
        scenario.sut.invalidate(.refresh(worktrees), at: .zero)
        _ = scenario.sut.takeDue(at: .milliseconds(400))
        scenario.sut.invalidate(.refresh(worktrees), at: .milliseconds(500))

        // when
        let during = scenario.sut.takeDue(at: .milliseconds(2_400))
        let blocked = scenario.sut.nextDeadline
        scenario.sut.didFinishRefresh(in: worktrees)
        let after = scenario.sut.takeDue(at: .seconds(5))

        // then
        #expect(during == .ignore)
        #expect(blocked == .none)
        #expect(after == .refresh(worktrees))
    }

    @Test
    func `given reconciliation is running when files change then their refresh waits for its completion`() {
        // given
        var scenario = Scenario()
        let worktrees: Set<WorktreeID> = [WorktreeID(canonicalPath: "/project")]
        scenario.sut.invalidate(.reconcile, at: .zero)
        _ = scenario.sut.takeDue(at: .milliseconds(400))
        scenario.sut.invalidate(.refresh(worktrees), at: .milliseconds(500))

        // when
        let during = scenario.sut.takeDue(at: .milliseconds(2_400))
        let blocked = scenario.sut.nextDeadline
        scenario.sut.didFinishReconciliation()
        let after = scenario.sut.takeDue(at: .seconds(5))

        // then
        #expect(during == .ignore)
        #expect(blocked == .none)
        #expect(after == .refresh(worktrees))
    }

    private struct Scenario {
        var sut = WorktreeObservationSchedule()
    }
}
