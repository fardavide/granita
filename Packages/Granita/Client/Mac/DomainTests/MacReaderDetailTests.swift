import Foundation
import Testing

import ClientMacDomain
import ClientWorktreesDomain
import CoreDiffDomain

@Suite("Mac reader detail")
struct MacReaderDetailTests {

    @Test(arguments: [
        (WorktreeSidebarState.loading, MacReaderDetail.blank),
        (.failed(.rateLimited), .blank),
        (.noProjects, .blank),
        (.allQuiet(worktreeCount: 3, projectNames: ["Granita"]), .blank),
        (.listing(WorktreeListing(sections: [], quietCount: 0)), .noWorktreeChosen)
    ])
    func `given no chosen worktree when resolving detail then choosing is offered only alongside a listing`(
        _ sidebar: WorktreeSidebarState,
        _ expected: MacReaderDetail
    ) {
        // given
        let selection = ReaderWorktreeSelection.none

        // when
        let scenario = Scenario(selection: selection, sidebar: sidebar, worktrees: [])

        // then
        #expect(scenario.sut == expected)
    }

    @Test
    func `given a chosen worktree with an old name when its current row is listed then detail uses the current display name`() {
        // given
        let id = WorktreeID(rawValue: "chosen-worktree-with-new-alias")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let worktree = Worktree(
            id: id,
            projectId: ProjectID(rawValue: "project-containing-the-chosen-worktree"),
            projectName: "Granita",
            branch: "codex/reader-navigation",
            isPrimary: false,
            isDetached: false,
            isLocked: false,
            hasUnbornHead: false,
            alias: "Updated reader navigation",
            suggestedAlias: nil,
            displayName: "Updated reader navigation",
            directoryName: "reader-navigation-checkout",
            isPinned: false,
            stats: ChangeStats(filesChanged: 3, insertions: 42, deletions: 11),
            lastModified: now,
            revision: "current-row-revision"
        )
        let sidebar = WorktreeSidebarState(
            of: [worktree],
            mode: .groupedByProject,
            showingQuiet: false,
            now: now
        )

        // when
        let scenario = Scenario(
            selection: .chosen(id, name: "Old captured review name"),
            sidebar: sidebar,
            worktrees: [worktree]
        )

        // then
        #expect(scenario.sut == .chosen(id, name: "Updated reader navigation"))
    }

    @Test
    func `given a chosen worktree absent from the full worktree list when resolving detail then gone names the captured worktree`() {
        // given
        let selection = ReaderWorktreeSelection.chosen(
            WorktreeID(rawValue: "chosen-worktree-no-longer-listed"),
            name: "Remembered navigation review"
        )
        let sidebar = WorktreeSidebarState.listing(WorktreeListing(sections: [], quietCount: 0))

        // when
        let scenario = Scenario(selection: selection, sidebar: sidebar, worktrees: [])

        // then
        #expect(scenario.sut == .gone(name: "Remembered navigation review"))
    }

    @Test(arguments: [false, true])
    func `given a chosen quiet worktree hidden from the sidebar when resolving detail then it remains chosen with its current name`(
        _ allQuiet: Bool
    ) {
        // given
        let id = WorktreeID(rawValue: "chosen-quiet-worktree-still-known")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let quiet = knownWorktree(id: id, name: "Current quiet review", stats: .zero, now: now)
        let busy = knownWorktree(
            id: WorktreeID(rawValue: "other-visible-busy-worktree"),
            name: "Other busy review",
            stats: ChangeStats(filesChanged: 2, insertions: 14, deletions: 3),
            now: now
        )
        let worktrees = allQuiet ? [quiet] : [quiet, busy]
        let sidebar = WorktreeSidebarState(
            of: worktrees,
            mode: .groupedByProject,
            showingQuiet: false,
            now: now
        )

        // when
        let scenario = Scenario(
            selection: .chosen(id, name: "Old captured quiet review"),
            sidebar: sidebar,
            worktrees: worktrees
        )

        // then
        #expect(scenario.sut == .chosen(id, name: "Current quiet review"))
    }

    private struct Scenario {
        let sut: MacReaderDetail

        init(selection: ReaderWorktreeSelection, sidebar: WorktreeSidebarState, worktrees: [Worktree]) {
            sut = MacReaderDetail(selection: selection, sidebar: sidebar, worktrees: worktrees)
        }
    }
}

private func knownWorktree(id: WorktreeID, name: String, stats: ChangeStats, now: Date) -> Worktree {
    Worktree(
        id: id,
        projectId: ProjectID(rawValue: "quiet-selection-project"),
        projectName: "Granita",
        branch: "codex/quiet-selection",
        isPrimary: false,
        isDetached: false,
        isLocked: false,
        hasUnbornHead: false,
        alias: name,
        suggestedAlias: nil,
        displayName: name,
        directoryName: "quiet-selection-checkout",
        isPinned: false,
        stats: stats,
        lastModified: now,
        revision: "known-worktree-revision"
    )
}
