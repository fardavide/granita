import Foundation
import Testing

import ClientConnectionDomain
import ClientWorktreesDomain
import CoreDiffDomain

@testable import ClientWorktreesPresentation

/// What the sidebar does, as opposed to what it looks like doing it.
///
/// Every control design §2 puts on this screen is driven from here, because a rendered picture
/// cannot say whether anything is behind a swipe.
@Suite("Client worktrees model")
@MainActor
struct ClientWorktreesModelTests {

    // MARK: - Reading

    @Test
    func `given a Mac with worktrees when loading then the list arrives arranged`() async {
        // given
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.state == WorktreeSidebarState(
            of: [aWorktree(named: "diff scroll", project: "granita")],
            mode: .groupedByProject,
            showingQuiet: false,
            now: aMoment
        ))
    }

    @Test
    func `given a Mac that cannot be reached when loading then the refusal is what is shown`() async {
        // given — a screen that stayed on its loading state would be a screen claiming the request
        // is still running when nothing is.
        let scenario = Scenario(worktrees: [], readFailure: .unreachable(diagnostic: "NWError -65563"))

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.state == .failed(.unreachable(diagnostic: "NWError -65563")))
    }

    @Test
    func `given nothing has been read yet when the model is built then it says it is loading`() {
        // given - when
        let scenario = Scenario(worktrees: [])

        // then
        #expect(scenario.sut.state == .loading)
    }

    // MARK: - The toolbar menu

    @Test
    func `given a loaded list when the mode changes then the list rearranges and the choice sticks`() async {
        // given
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()

        // when
        scenario.sut.show(.mostRecentFirst)

        // then — rearranged without another request, because the same worktrees answer both modes
        // and a round trip to reorder a list already on screen is a spinner for nothing.
        #expect(scenario.sut.mode == .mostRecentFirst)
        #expect(scenario.sut.state == WorktreeSidebarState(
            of: [aWorktree(named: "diff scroll", project: "granita")],
            mode: .mostRecentFirst,
            showingQuiet: false,
            now: aMoment
        ))
        #expect(scenario.preferences.mode() == .mostRecentFirst)
    }

    @Test
    func `given quiet worktrees are hidden when they are shown then they appear and the choice sticks`() async {
        // given
        let scenario = Scenario(worktrees: [
            aWorktree(named: "diff scroll", project: "granita"),
            aClean(named: "main", project: "granita")
        ])
        await scenario.sut.load()

        // when
        scenario.sut.showQuietWorktrees(true)

        // then
        #expect(scenario.sut.showsQuietWorktrees)
        #expect(scenario.preferences.showsQuietWorktrees())
        #expect(scenario.rows.map(\.displayName) == ["diff scroll", "main"])
    }

    @Test
    func `given a remembered arrangement when the model is built then it opens that way`() async {
        // given — the whole reason §2 chose a menu over a segmented band: a preference set once.
        let scenario = Scenario(
            worktrees: [aWorktree(named: "diff scroll", project: "granita")],
            preferences: FakeWorktreeListPreferences(mode: .mostRecentFirst, showsQuiet: true)
        )

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.sut.mode == .mostRecentFirst)
        #expect(scenario.sut.showsQuietWorktrees)
    }

    @Test
    func `given nothing loaded yet when the mode changes then the choice still sticks`() {
        // given — the menu is reachable while the first request is in flight, and a preference that
        // was accepted on screen and then forgotten is a control that lied about what it did.
        let scenario = Scenario(worktrees: [])

        // when
        scenario.sut.show(.mostRecentFirst)

        // then
        #expect(scenario.sut.state == .loading)
        #expect(scenario.preferences.mode() == .mostRecentFirst)
    }

    @Test
    func `given the Mac could not be reached when the mode changes then the refusal stays up`() async {
        // given — rearranging an empty list here would replace "could not reach your Mac" with
        // "no projects yet", which is a different claim and a false one.
        let scenario = Scenario(worktrees: [], readFailure: .rateLimited)
        await scenario.sut.load()

        // when
        scenario.sut.show(.mostRecentFirst)

        // then
        #expect(scenario.sut.state == .failed(.rateLimited))
    }

    @Test
    func `given a Mac that refused once when it is read again then the list replaces the refusal`() async {
        // given — Try Again has to be able to reach a list, or it is a button whose only effect is
        // the same screen it was pressed on.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()

        // when
        await scenario.sut.load()

        // then
        #expect(scenario.rows.map(\.displayName) == ["diff scroll"])
    }

    // MARK: - Renaming

    @Test
    func `given a worktree when it is renamed then only the alias is written`() async {
        // given — the one rule renaming has: it names a checkout on the phone and never touches git.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()

        // when
        await scenario.sut.rename(WorktreeID(rawValue: "w-diff scroll"), to: "Scroll rewrite")

        // then
        let patches = await scenario.repository.patches
        #expect(patches.count == 1)
        #expect(patches.first?.worktree == WorktreeID(rawValue: "w-diff scroll"))
        #expect(patches.first?.patch == WorktreePatch(alias: .set("Scroll rewrite"), isPinned: nil))
    }

    @Test
    func `given a worktree when it is renamed then the row says so without another request`() async {
        // given
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()

        // when
        await scenario.sut.rename(WorktreeID(rawValue: "w-diff scroll"), to: "Scroll rewrite")

        // then
        #expect(scenario.rows.map(\.displayName) == ["Scroll rewrite"])
    }

    @Test
    func `given an alias when the field is cleared then the patch says cleared rather than empty`() async {
        // given — a plain struct cannot tell "clear the alias" from "leave it alone", and an empty
        // string would be a third meaning the Mac has no case for. This is the trap SPEC §8 marks.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita", alias: "Scroll")])
        await scenario.sut.load()

        // when
        await scenario.sut.rename(WorktreeID(rawValue: "w-diff scroll"), to: "   ")

        // then
        let patches = await scenario.repository.patches
        #expect(patches.first?.patch == WorktreePatch(alias: .cleared, isPinned: nil))
    }

    @Test
    func `given a rename the Mac refused when it is saved then the reader is told`() async {
        // given — the row would otherwise snap back to its old name with no explanation, which
        // reads as the app having ignored the tap.
        let scenario = Scenario(
            worktrees: [aWorktree(named: "diff scroll", project: "granita")],
            writeFailure: .worktreeGone
        )
        await scenario.sut.load()

        // when
        await scenario.sut.rename(WorktreeID(rawValue: "w-diff scroll"), to: "Scroll rewrite")

        // then
        #expect(scenario.sut.writeFailure == .worktreeGone)
        #expect(scenario.rows.map(\.displayName) == ["diff scroll"])
    }

    @Test
    func `given a refusal on screen when it is dismissed then it does not come back`() async {
        // given
        let scenario = Scenario(
            worktrees: [aWorktree(named: "diff scroll", project: "granita")],
            writeFailure: .worktreeGone
        )
        await scenario.sut.load()
        await scenario.sut.rename(WorktreeID(rawValue: "w-diff scroll"), to: "Scroll rewrite")

        // when
        scenario.sut.dismissWriteFailure()

        // then
        #expect(scenario.sut.writeFailure == nil)
    }

    @Test
    func `given the sheet is open when it is cancelled then nothing is written`() async throws {
        // given
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()
        let row = try #require(scenario.rows.first)

        // when
        scenario.sut.beginRenaming(row.rename)
        scenario.sut.cancelRenaming()

        // then
        let patches = await scenario.repository.patches
        #expect(scenario.sut.renaming == nil)
        #expect(patches.isEmpty)
    }

    @Test
    func `given a row when renaming begins then the sheet is handed that row's own fallback`() async throws {
        // given — the sheet's footer states what the row will read after Save, so it has to be the
        // subject the row itself resolved rather than one the sheet works out again.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita", alias: "Scroll")])
        await scenario.sut.load()
        let row = try #require(scenario.rows.first)

        // when
        scenario.sut.beginRenaming(row.rename)

        // then
        #expect(scenario.sut.renaming?.derivedName == "diff scroll")
        #expect(scenario.sut.renaming?.alias == "Scroll")
    }

    // MARK: - Pinning

    @Test
    func `given an unpinned worktree when it is pinned then only the pin is written`() async {
        // given
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()

        // when
        await scenario.sut.setPinned(true, on: WorktreeID(rawValue: "w-diff scroll"))

        // then
        let patches = await scenario.repository.patches
        #expect(patches.first?.patch == WorktreePatch(alias: .unchanged, isPinned: true))
    }

    @Test
    func `given a pinned worktree when it is unpinned then the list rearranges around it`() async {
        // given — the pin's whole effect is where the row sits, so a pin that wrote and left the
        // list where it was would be a control with nothing to show for itself.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "diff scroll", project: "granita", pinned: true),
            aWorktree(named: "session index", project: "granita", minutesAgo: 1)
        ])
        await scenario.sut.load()
        #expect(scenario.sections.map(\.id) == [
            .pinned, .project(ProjectID(rawValue: "granita"), name: "granita")
        ])

        // when
        await scenario.sut.setPinned(false, on: WorktreeID(rawValue: "w-diff scroll"))

        // then
        #expect(scenario.sections.map(\.id) == [.project(ProjectID(rawValue: "granita"), name: "granita")])
        #expect(scenario.rows.map(\.displayName) == ["session index", "diff scroll"])
    }

    @Test
    func `given a pin the Mac refused when it is set then the reader is told`() async {
        // given
        let scenario = Scenario(
            worktrees: [aWorktree(named: "diff scroll", project: "granita")],
            writeFailure: .unauthorized
        )
        await scenario.sut.load()

        // when
        await scenario.sut.setPinned(true, on: WorktreeID(rawValue: "w-diff scroll"))

        // then
        #expect(scenario.sut.writeFailure == .unauthorized)
    }

    @Test
    func `given a worktree the Mac no longer serves when writing then the list is not corrupted`() async {
        // given — an agent removes a worktree every day, and the answer arriving about one that is
        // gone must not put a row in the list that is not in the list.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()

        // when
        await scenario.sut.setPinned(true, on: WorktreeID(rawValue: "w-vanished"))

        // then
        #expect(scenario.sut.writeFailure == .worktreeGone)
        #expect(scenario.rows.map(\.displayName) == ["diff scroll"])
    }

    // MARK: -

    private struct Scenario {

        let sut: ClientWorktreesModel
        let repository: FakeGranitaRepository
        let preferences: FakeWorktreeListPreferences

        /// Empty for every state that is not a list, so a test that expected rows and got a refusal
        /// fails on the rows rather than on a pattern match three lines earlier.
        var sections: [WorktreeListSection] {
            guard case .listing(let listing) = sut.state else { return [] }
            return listing.sections
        }

        /// Flattened, because most assertions here are about which rows are on screen in what order
        /// and the sections they arrive under are a separate question with its own tests.
        var rows: [WorktreeListRow] {
            sections.flatMap(\.rows)
        }

        init(
            worktrees: [Worktree],
            readFailure: ApiFailure? = nil,
            writeFailure: ApiFailure? = nil,
            preferences: FakeWorktreeListPreferences = FakeWorktreeListPreferences()
        ) {
            repository = FakeGranitaRepository(
                worktrees: worktrees,
                readFailure: readFailure,
                writeFailure: writeFailure
            )
            self.preferences = preferences
            sut = ClientWorktreesModel(
                repository: repository,
                preferences: preferences,
                now: { aMoment }
            )
        }
    }
}

// MARK: -

/// Fixed rather than `Date()`, so an age never depends on how long the suite took to reach it.
///
/// Explicitly nonisolated because this target is main-actor by default and the model's clock is a
/// `@Sendable` closure, which cannot reach across to the main actor to read it.
private nonisolated let aMoment = Date(timeIntervalSince1970: 1_800_000_000)

private func aWorktree(
    named name: String,
    project: String,
    alias: String? = nil,
    pinned: Bool = false,
    minutesAgo: Int = 4
) -> Worktree {
    Worktree(
        id: WorktreeID(rawValue: "w-\(name)"),
        projectId: ProjectID(rawValue: project),
        projectName: project,
        branch: name,
        isPrimary: false,
        isDetached: false,
        isLocked: false,
        hasUnbornHead: false,
        alias: alias,
        suggestedAlias: nil,
        displayName: alias ?? name,
        directoryName: "d-\(name)",
        isPinned: pinned,
        stats: ChangeStats(filesChanged: 12, insertions: 248, deletions: 31),
        lastModified: aMoment.addingTimeInterval(TimeInterval(-minutesAgo * 60)),
        revision: "r1"
    )
}

private func aClean(named name: String, project: String) -> Worktree {
    Worktree(
        id: WorktreeID(rawValue: "w-\(name)"),
        projectId: ProjectID(rawValue: project),
        projectName: project,
        branch: name,
        isPrimary: true,
        isDetached: false,
        isLocked: false,
        hasUnbornHead: false,
        alias: nil,
        suggestedAlias: nil,
        displayName: name,
        directoryName: name,
        isPinned: false,
        stats: .zero,
        lastModified: aMoment.addingTimeInterval(-3 * 86_400),
        revision: "r1"
    )
}
