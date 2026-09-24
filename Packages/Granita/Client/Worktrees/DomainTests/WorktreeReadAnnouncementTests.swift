import Testing

import ClientConnectionDomain

@testable import ClientWorktreesDomain

@Suite("Worktree read announcement")
struct WorktreeReadAnnouncementTests {

    @Test(arguments: [
        (WorktreeReadStage.finding(.unknown), "Finding Studio Mac. Looking for your Mac."),
        (.finding(.local), "Finding Studio Mac. Looking on this network."),
        (.finding(.tailnet), "Finding Studio Mac. Looking over Tailscale. Finding it on this network needs Wi-Fi."),
        (.finding(.localAndTailnet), "Finding Studio Mac. Looking on this network and over Tailscale."),
        (.verifying, "Verifying Studio Mac. Checking it against the key this device pinned when it paired."),
        (.reading(.unknown), "Reading worktrees. Waiting for your Mac’s response."),
        (.reading(.local), "Reading worktrees. Connected on this network."),
        (.reading(.tailnet), "Reading worktrees. Connected over Tailscale."),
        (.reading(.thisMac), "Reading worktrees. Running git on this Mac.")
    ])
    func `given an observed read stage when announcing it then the label and connection facts are combined`(
        stage: WorktreeReadStage,
        expected: String
    ) {
        // given
        let scenario = Scenario(announcement: .stage(stage, macName: "Studio Mac"))

        // when
        let sentence = scenario.sut.sentence

        // then
        #expect(sentence == expected)
    }

    @Test
    func `given refresh failed when announcing it then the previous worktrees are still available`() {
        // given
        let scenario = Scenario(announcement: .refreshFailed)

        // when
        let sentence = scenario.sut.sentence

        // then
        #expect(sentence == "Couldn't refresh. Your previous worktrees are still available.")
    }

    @Test(arguments: [
        (7, "Read 7 worktrees."),
        (1, "Read 1 worktree.")
    ])
    func `given a completed read count when announcing arrival then the sentence agrees with the count`(
        worktreeCount: Int,
        expected: String
    ) {
        // given
        let scenario = Scenario(worktreeCount: worktreeCount)

        // when
        let sentence = scenario.sut.sentence

        // then
        #expect(sentence == expected)
    }

    private struct Scenario {
        let sut: WorktreeReadAnnouncement

        init(worktreeCount: Int) {
            sut = .arrived(worktreeCount: worktreeCount)
        }

        init(announcement: WorktreeReadAnnouncement) {
            sut = announcement
        }
    }
}
