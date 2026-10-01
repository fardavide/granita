import Testing

import ClientConnectionDomain
import ClientMacDomain
import ClientMacPresentation
import CoreDiffDomain
import ServerApiDomain

@Suite("Mac reader selection")
struct ClientMacModelTests {

    @Test
    func `given a remembered remote Mac and worktree when the reader opens then both are restored`() {
        // given
        let remembered = ReaderSelection(
            source: .remote(DiscoveredServer(
                id: BonjourInstanceName(rawValue: "review-studio-instance"),
                name: "Review Studio"
            )),
            worktree: .chosen(WorktreeID(rawValue: "worktree-last-reviewed-on-studio"), name: "Studio review")
        )

        // when
        let scenario = Scenario(remembering: remembered)

        // then
        #expect(scenario.sut.selection == remembered)
    }

    @Test
    func `given a remote worktree when choosing this Mac then the old worktree is cleared and remembered`() {
        // given
        let scenario = Scenario(remembering: ReaderSelection(
            source: .remote(DiscoveredServer(
                id: BonjourInstanceName(rawValue: "other-mac-instance"),
                name: "Other Mac"
            )),
            worktree: .chosen(WorktreeID(rawValue: "other-mac-worktree"), name: "Other Mac review")
        ))
        let expected = ReaderSelection(source: .thisMac, worktree: .none)

        // when
        scenario.sut.choose(source: .thisMac)

        // then
        #expect(scenario.sut.selection == expected)
        #expect(scenario.memory.read() == expected)
    }

    @Test(arguments: [
        (ServerRunState.starting, true),
        (.running(ServerEndpoint(host: "192.168.1.42", port: 8737)), true),
        (.failed(reason: "Local Network access refused"), true),
        (.stopped, true),
        (.blockedByAnotherProcess(nil), false)
    ])
    func `given the server state when checking local read access then only another process blocks it`(
        _ serverState: ServerRunState,
        _ expected: Bool
    ) {
        // given
        let scenario = Scenario(remembering: ReaderSelection(source: .thisMac, worktree: .none))

        // when
        let canRead = scenario.sut.canReadLocal(serverState: serverState)

        // then
        #expect(canRead == expected)
    }

    @Test
    func `given a chosen worktree when choosing the same source then the worktree is retained`() {
        // given
        let selection = ReaderSelection(
            source: .thisMac,
            worktree: .chosen(WorktreeID(rawValue: "worktree-kept-on-this-mac"), name: "Kept local review")
        )
        let scenario = Scenario(remembering: selection)

        // when
        scenario.sut.choose(source: .thisMac)

        // then
        #expect(scenario.sut.selection == selection)
        #expect(scenario.memory.read() == selection)
    }

    @Test
    func `given this Mac when choosing a worktree then the worktree is selected and remembered`() {
        // given
        let scenario = Scenario(remembering: ReaderSelection(source: .thisMac, worktree: .none))
        let worktree = WorktreeID(rawValue: "this-mac-worktree-being-reviewed")
        let expected = ReaderSelection(source: .thisMac, worktree: .chosen(worktree, name: "Current local review"))

        // when
        scenario.sut.choose(worktree: .chosen(worktree, name: "Current local review"))

        // then
        #expect(scenario.sut.selection == expected)
        #expect(scenario.memory.read() == expected)
    }

    private struct Scenario {

        let sut: ClientMacModel
        let memory: FakeReaderSelectionMemory

        init(remembering selection: ReaderSelection) {
            memory = FakeReaderSelectionMemory(remembering: selection)
            sut = ClientMacModel(memory: memory)
        }
    }
}
