import Foundation
import Testing

import ClientConnectionDomain

@testable import ClientWorktreesDomain

@Suite("Worktree read result")
struct WorktreeReadResultTests {

    @Test
    func `given a refresh failed fourteen minutes after reading when describing the notice then it names the failure and age`() {
        // given
        let scenario = Scenario(
            result: .stale(
                at: Date(timeIntervalSince1970: 1_800_000_000),
                route: .local,
                failure: .unreachable(diagnostic: "The refresh timed out")
            ),
            now: Date(timeIntervalSince1970: 1_800_000_840)
        )

        // when
        let notice = scenario.sut.refreshNotice(at: scenario.now)

        // then
        #expect(notice == "Couldn't refresh. These worktrees were read 14 minutes ago.")
    }

    @Test(arguments: [
        (60.0, "Read 1 minute ago."),
        (3_600.0, "Read 1 hour ago."),
        (86_400.0, "Read 1 day ago."),
        (7_200.0, "Read 2 hours ago."),
        (172_800.0, "Read 2 days ago.")
    ])
    func `given a read age in minutes hours or days when describing the footer then its time unit agrees with its count`(
        elapsed: Double,
        expected: String
    ) {
        // given
        let scenario = Scenario(
            result: .read(at: Date(timeIntervalSince1970: 1_800_000_000), route: .unknown),
            now: Date(timeIntervalSince1970: 1_800_000_000 + elapsed)
        )

        // when
        let footer = scenario.sut.footer(at: scenario.now)

        // then
        #expect(footer == expected)
    }

    @Test(arguments: [
        (WorktreeReadResult.read(at: Date(timeIntervalSince1970: 1_800_000_000), route: .local), 0.0, "Read just now, on this network."),
        (.read(at: Date(timeIntervalSince1970: 1_800_000_000), route: .tailnet), 840.0, "Read 14 minutes ago, over Tailscale."),
        (.read(at: Date(timeIntervalSince1970: 1_800_000_000), route: .unknown), 0.0, "Read just now."),
        (.notRead, 840.0, ""),
        (.stale(at: Date(timeIntervalSince1970: 1_800_000_000), route: .local, failure: .unreachable(diagnostic: "The refresh timed out")), 840.0, "Showing worktrees read 14 minutes ago.")
    ])
    func `given a read receipt and the current time when describing the footer then its actual age and known route are shown`(
        result: WorktreeReadResult,
        elapsed: Double,
        expected: String
    ) {
        // given
        let scenario = Scenario(result: result, now: Date(timeIntervalSince1970: 1_800_000_000 + elapsed))

        // when
        let footer = scenario.sut.footer(at: scenario.now)

        // then
        #expect(footer == expected)
    }

    private struct Scenario {
        let sut: WorktreeReadResult
        let now: Date

        init(result: WorktreeReadResult, now: Date) {
            sut = result
            self.now = now
        }
    }
}
