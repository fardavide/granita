import Testing

import ClientConnectionDomain

@testable import ClientWorktreesDomain

@Suite("Worktree loading description")
struct WorktreeLoadingDescriptionTests {

    @Test(arguments: [
        (WorktreeReadStage.finding(.local), 9.9, "Finding Studio Mac", false),
        (.finding(.local), 10.0, "Still finding Studio Mac", true),
        (.verifying, 10.0, "Still verifying Studio Mac", true),
        (.reading(.tailnet), 42.0, "Still reading worktrees", true)
    ])
    func `given an attempt elapsed time when describing the wait then long wait feedback begins at ten seconds`(
        stage: WorktreeReadStage,
        elapsed: Double,
        headline: String,
        isLongWait: Bool
    ) {
        // given
        let scenario = Scenario(stage: stage, elapsed: elapsed)

        // when
        let description = scenario.sut

        // then
        #expect(description.headline == headline)
        #expect(description.isLongWait == isLongWait)
    }

    @Test(arguments: [
        (WorktreeReadStage.finding(.unknown), "Finding Studio Mac", "Looking for your Mac."),
        (.finding(.local), "Finding Studio Mac", "Looking on this network."),
        (.finding(.tailnet), "Finding Studio Mac", "Looking over Tailscale. Finding it on this network needs Wi-Fi."),
        (.finding(.localAndTailnet), "Finding Studio Mac", "Looking on this network and over Tailscale."),
        (.verifying, "Verifying Studio Mac", "Checking it against the key this device pinned when it paired."),
        (.reading(.unknown), "Reading worktrees", "Waiting for your Mac’s response."),
        (.reading(.local), "Reading worktrees", "Connected on this network."),
        (.reading(.tailnet), "Reading worktrees", "Connected over Tailscale."),
        // There is no response to wait for and no connection to name: the read is this process
        // running git. Every other sentence here describes a network that is not in the path.
        (.reading(.thisMac), "Reading worktrees", "Running git on this Mac.")
    ])
    func `given an observed stage when describing the wait then only observed connection facts are named`(
        stage: WorktreeReadStage,
        headline: String,
        sentence: String
    ) {
        // given
        let scenario = Scenario(stage: stage)

        // when
        let description = scenario.sut

        // then
        #expect(description.headline == headline)
        #expect(description.sentence == sentence)
    }

    private struct Scenario {
        let sut: WorktreeLoadingDescription

        init(stage: WorktreeReadStage, elapsed: Double = 3) {
            sut = WorktreeLoadingDescription(stage: stage, macName: "Studio Mac", elapsed: elapsed)
        }
    }
}
