import Foundation
import Testing

import ClientConnectionDomain
import CoreDiffDomain

@testable import ClientWorktreesDomain

/// Design §2 is almost entirely a set of ordering and drop rules, and every one of them is decided
/// here rather than in a view body — which is what lets them be asserted without a renderer.
@Suite("Worktree listing")
struct WorktreeListingTests {

    // MARK: - Grouping and order

    @Test
    func `given pinned worktrees across projects when grouping then one Pinned section leads`() {
        // given — the objection this answers is that a pinned worktree then sits away from its
        // siblings. One section at the top, not a float within each project.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "quiet refactor", project: "aura", pinned: false, minutesAgo: 20),
            aWorktree(named: "session index", project: "granita", pinned: false, minutesAgo: 10),
            aWorktree(named: "TLS pinning", project: "granita", pinned: true, minutesAgo: 4),
            aWorktree(named: "coverage script", project: "aura", pinned: true, minutesAgo: 90)
        ])

        // when
        let listing = scenario.listing(mode: .groupedByProject)

        // then
        #expect(listing.sections.map(\.id) == [
            .pinned,
            .project(ProjectID(rawValue: "granita"), name: "granita"),
            .project(ProjectID(rawValue: "aura"), name: "aura")
        ])
        #expect(listing.sections[0].rows.map(\.displayName) == ["TLS pinning", "coverage script"])
    }

    @Test
    func `given a pinned worktree when grouping then it is lifted rather than copied`() {
        // given — a row that appears twice is a worse bug than a row that appears once in a
        // surprising place, and the project name on line two is what makes the place unsurprising.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "TLS pinning", project: "granita", pinned: true, minutesAgo: 4),
            aWorktree(named: "session index", project: "granita", pinned: false, minutesAgo: 22)
        ])

        // when
        let listing = scenario.listing(mode: .groupedByProject)

        // then
        #expect(listing.sections[1].rows.map(\.displayName) == ["session index"])
    }

    @Test
    func `given a project whose only worktree is pinned when grouping then it grows no header`() {
        // given — a header with nothing under it says a project is here and then shows a gap.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "TLS pinning", project: "granita", pinned: true, minutesAgo: 4)
        ])

        // when
        let listing = scenario.listing(mode: .groupedByProject)

        // then
        #expect(listing.sections.map(\.id) == [.pinned])
    }

    @Test
    func `given a pinned worktree when grouping then it keeps its project name on line two`() {
        // given — the fix for the orphaning objection is one field, not a different structure: the
        // pinned row is the only row in grouped mode carrying a project name, and that difference is
        // what explains where it came from.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "TLS pinning", project: "granita", pinned: true, minutesAgo: 4),
            aWorktree(named: "session index", project: "granita", pinned: false, minutesAgo: 22)
        ])

        // when
        let listing = scenario.listing(mode: .groupedByProject)

        // then
        #expect(listing.sections[0].rows.map(\.projectName) == ["granita"])
        #expect(listing.sections[1].rows.map(\.projectName) == [nil])
    }

    @Test
    func `given grouped mode when a section carries the pin then no row draws a pin glyph`() {
        // given
        let scenario = Scenario(worktrees: [
            aWorktree(named: "TLS pinning", project: "granita", pinned: true, minutesAgo: 4)
        ])

        // when
        let grouped = scenario.listing(mode: .groupedByProject)
        let flat = scenario.listing(mode: .mostRecentFirst)

        // then — one or the other, never both. Flat mode has no header to carry it.
        #expect(grouped.sections[0].rows[0].showsPinIndicator == false)
        #expect(flat.sections[0].rows[0].showsPinIndicator)
    }

    @Test
    func `given several projects when grouping then the busiest-lately project leads`() {
        // given — the frames put granita above aura while aura sorts first alphabetically, so the
        // order is activity and not the name. The name is only what breaks a tie.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "coverage script", project: "aura", pinned: false, minutesAgo: 300),
            aWorktree(named: "session index", project: "granita", pinned: false, minutesAgo: 22)
        ])

        // when
        let listing = scenario.listing(mode: .groupedByProject)

        // then
        #expect(listing.sections.map(\.id) == [
            .project(ProjectID(rawValue: "granita"), name: "granita"),
            .project(ProjectID(rawValue: "aura"), name: "aura")
        ])
    }

    @Test
    func `given two projects last touched together when grouping then the name breaks the tie`() {
        // given — a deterministic order matters more than which one wins: a list that reshuffles
        // between two identical reads is a list nobody can navigate by memory.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "second", project: "zulu", pinned: false, minutesAgo: 10),
            aWorktree(named: "first", project: "alpha", pinned: false, minutesAgo: 10)
        ])

        // when
        let listing = scenario.listing(mode: .groupedByProject)

        // then
        #expect(listing.sections.map(\.id) == [
            .project(ProjectID(rawValue: "alpha"), name: "alpha"),
            .project(ProjectID(rawValue: "zulu"), name: "zulu")
        ])
    }

    @Test
    func `given flat mode when listing then pinned lead and the rest follow most recent first`() {
        // given
        let scenario = Scenario(worktrees: [
            aWorktree(named: "session index", project: "granita", pinned: false, minutesAgo: 22),
            aWorktree(named: "coverage script", project: "aura", pinned: true, minutesAgo: 300),
            aWorktree(named: "diff scroll", project: "granita", pinned: false, minutesAgo: 4)
        ])

        // when
        let listing = scenario.listing(mode: .mostRecentFirst)

        // then — pinned sort above everything in both modes, and there is exactly one section
        // because a flat list has no headers to hang the pin on.
        #expect(listing.sections.map(\.id) == [.everything])
        #expect(listing.sections[0].rows.map(\.displayName) == [
            "coverage script", "diff scroll", "session index"
        ])
    }

    @Test
    func `given flat mode when listing then every row promotes its project name`() {
        // given — without it a flat list of agent sentences has no idea what codebase it is talking
        // about, which is the one field this mode cannot lose.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "session index", project: "granita", pinned: false, minutesAgo: 22)
        ])

        // when
        let listing = scenario.listing(mode: .mostRecentFirst)

        // then
        #expect(listing.sections[0].rows[0].projectName == "granita")
    }

    // MARK: - Hiding the quiet ones

    @Test
    func `given worktrees with no changes when hiding them then the count is stated`() {
        // given — the count is what reconciles this list with the Mac's, so it is carried rather
        // than left to a reader to notice.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "diff scroll", project: "granita", pinned: false, minutesAgo: 4),
            aClean(named: "main", project: "granita", minutesAgo: 4_320),
            aClean(named: "spike", project: "aura", minutesAgo: 60)
        ])

        // when
        let listing = scenario.listing(mode: .mostRecentFirst, showingQuiet: false)

        // then
        #expect(listing.sections[0].rows.map(\.displayName) == ["diff scroll"])
        #expect(listing.quietCount == 2)
    }

    @Test
    func `given quiet worktrees shown when listing then none are hidden and none are counted`() {
        // given
        let scenario = Scenario(worktrees: [
            aWorktree(named: "diff scroll", project: "granita", pinned: false, minutesAgo: 4),
            aClean(named: "main", project: "granita", minutesAgo: 4_320)
        ])

        // when
        let listing = scenario.listing(mode: .mostRecentFirst, showingQuiet: true)

        // then
        #expect(listing.sections[0].rows.map(\.displayName) == ["diff scroll", "main"])
        #expect(listing.quietCount == 0)
    }

    @Test
    func `given a project whose worktrees are all quiet when hiding them then its section goes`() {
        // given — a header over nothing is chrome that says a project is here and then shows the
        // reader an empty gap where its rows would be.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "diff scroll", project: "granita", pinned: false, minutesAgo: 4),
            aClean(named: "spike", project: "aura", minutesAgo: 60)
        ])

        // when
        let listing = scenario.listing(mode: .groupedByProject, showingQuiet: false)

        // then
        #expect(listing.sections.map(\.id) == [.project(ProjectID(rawValue: "granita"), name: "granita")])
    }

    // MARK: - What the row says

    @Test
    func `given a worktree with no name of its own when listing then the row is a machine string`() {
        // given — a generated directory name is the one string that can never say what the agent
        // did, and the font is what carries that without spending a colour.
        let scenario = Scenario(worktrees: [
            Worktree(
                id: WorktreeID(rawValue: "w-detached"),
                projectId: ProjectID(rawValue: "aura"),
                projectName: "aura",
                branch: nil,
                isPrimary: false,
                isDetached: true,
                isLocked: false,
                hasUnbornHead: false,
                alias: nil,
                suggestedAlias: nil,
                displayName: "bridge-cse_01W9sY8PbT2Du1dFGeYGcwWo",
                directoryName: "bridge-cse_01W9sY8PbT2Du1dFGeYGcwWo",
                isPinned: false,
                stats: ChangeStats(filesChanged: 8, insertions: 96, deletions: 204),
                lastModified: aMoment.addingTimeInterval(-5 * 3_600),
                revision: "r1"
            )
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then — and detachment earns a word only here, where it answers "why is this row a random
        // string?" rather than flagging git state nobody reading a diff cares about.
        #expect(row.nameTier == .machineGenerated)
        #expect(row.showsDetached)
    }

    @Test
    func `given a detached worktree the reader named when listing then detachment stays off`() {
        // given
        let scenario = Scenario(worktrees: [
            Worktree(
                id: WorktreeID(rawValue: "w-named"),
                projectId: ProjectID(rawValue: "aura"),
                projectName: "aura",
                branch: nil,
                isPrimary: false,
                isDetached: true,
                isLocked: false,
                hasUnbornHead: false,
                alias: "Toolchain spike",
                suggestedAlias: nil,
                displayName: "Toolchain spike",
                directoryName: "bridge-cse_01W9sY8PbT2Du1dFGeYGcwWo",
                isPinned: false,
                stats: ChangeStats(filesChanged: 8, insertions: 96, deletions: 204),
                lastModified: aMoment.addingTimeInterval(-5 * 3_600),
                revision: "r1"
            )
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then
        #expect(row.nameTier == .named)
        #expect(row.showsDetached == false)
    }

    @Test
    func `given a worktree named by its branch when listing then the name is trusted`() {
        // given — a branch name usually can say what the agent did, so it is not a machine string.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "feat/session-index", project: "granita", pinned: false, minutesAgo: 22)
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then
        #expect(row.nameTier == .named)
    }

    @Test
    func `given an unborn head when listing then the stats slot says so instead of counting`() {
        // given — everything compares against the empty tree, so the real numbers are the whole
        // repository and they are a lie about what changed.
        let scenario = Scenario(worktrees: [
            Worktree(
                id: WorktreeID(rawValue: "w-unborn"),
                projectId: ProjectID(rawValue: "granita"),
                projectName: "granita",
                branch: "main",
                isPrimary: true,
                isDetached: false,
                isLocked: false,
                hasUnbornHead: true,
                alias: nil,
                suggestedAlias: nil,
                displayName: "main",
                directoryName: "granita",
                isPinned: false,
                stats: ChangeStats(filesChanged: 1_204, insertions: 84_002, deletions: 0),
                lastModified: aMoment.addingTimeInterval(-2 * 86_400),
                revision: "r1"
            )
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst, showingQuiet: true).sections[0].rows[0]

        // then
        #expect(row.stats == .noCommitsYet)
        #expect(row.isPrimaryCheckout)
    }

    @Test
    func `given a clean worktree when listing then the stats slot says no changes`() {
        // given
        let scenario = Scenario(worktrees: [aClean(named: "main", project: "granita", minutesAgo: 4_320)])

        // when
        let row = scenario.listing(mode: .mostRecentFirst, showingQuiet: true).sections[0].rows[0]

        // then — no dimming and no other treatment: a 312-file row is already the heavier one.
        #expect(row.stats == .noChanges)
    }

    @Test
    func `given a worktree with changes when listing then all three figures reach the row`() {
        // given
        let scenario = Scenario(worktrees: [
            aWorktree(named: "diff scroll", project: "granita", pinned: false, minutesAgo: 22)
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then
        #expect(row.stats == .changed(filesChanged: 34, insertions: 1_204, deletions: 318))
    }

    // MARK: - The trailing time

    @Test(arguments: [
        (0, WorktreeAge.underAMinute, "now"),
        (4, WorktreeAge.minutes(4), "4m"),
        (22, WorktreeAge.minutes(22), "22m"),
        (120, WorktreeAge.hours(2), "2h"),
        (4_320, WorktreeAge.days(3), "3d")
    ])
    func `given a moment when measuring against now then the age is coarse and short`(
        minutesAgo: Int,
        expected: WorktreeAge,
        label: String
    ) {
        // given
        let scenario = Scenario(worktrees: [
            aWorktree(named: "diff scroll", project: "granita", pinned: false, minutesAgo: minutesAgo)
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then
        #expect(row.age == expected)
        #expect(row.age.label == label)
    }

    @Test
    func `given a worktree touched after this phone thinks now is when listing then the age is now`() {
        // given — the two clocks are a Mac's and a phone's and nothing keeps them together, so a
        // negative interval is ordinary rather than impossible.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "diff scroll", project: "granita", pinned: false, minutesAgo: -30)
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then
        #expect(row.age == .underAMinute)
    }

    // MARK: - What the rename sheet is handed

    @Test
    func `given a worktree with a session suggestion when clearing the alias then it falls back to it`() {
        // given — the footer states what the row will read after Save, so the fallback has to be the
        // server's own resolution minus the alias. Skipping the suggestion would make that sentence
        // a lie in the one case a reader is checking it.
        let scenario = Scenario(worktrees: [
            Worktree(
                id: WorktreeID(rawValue: "w-suggested"),
                projectId: ProjectID(rawValue: "granita"),
                projectName: "granita",
                branch: "feat/tls-pinning",
                isPrimary: false,
                isDetached: false,
                isLocked: false,
                hasUnbornHead: false,
                alias: "TLS pinning",
                suggestedAlias: "Add TLS certificate pinning to the pairing handshake",
                displayName: "TLS pinning",
                directoryName: "granita-tls",
                isPinned: false,
                stats: ChangeStats(filesChanged: 12, insertions: 248, deletions: 31),
                lastModified: aMoment.addingTimeInterval(-4 * 60),
                revision: "r1"
            )
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then
        #expect(row.rename == WorktreeRenameSubject(
            worktree: WorktreeID(rawValue: "w-suggested"),
            alias: "TLS pinning",
            suggestedAlias: "Add TLS certificate pinning to the pairing handshake",
            derivedName: "Add TLS certificate pinning to the pairing handshake",
            derivedNameSource: .sessionSuggestion
        ))
    }

    @Test
    func `given no suggestion when clearing the alias then it falls back to the branch`() {
        // given
        let scenario = Scenario(worktrees: [
            Worktree(
                id: WorktreeID(rawValue: "w-branch"),
                projectId: ProjectID(rawValue: "granita"),
                projectName: "granita",
                branch: "feat/tls-pinning",
                isPrimary: false,
                isDetached: false,
                isLocked: false,
                hasUnbornHead: false,
                alias: "TLS pinning",
                suggestedAlias: nil,
                displayName: "TLS pinning",
                directoryName: "granita-tls",
                isPinned: false,
                stats: ChangeStats(filesChanged: 12, insertions: 248, deletions: 31),
                lastModified: aMoment.addingTimeInterval(-4 * 60),
                revision: "r1"
            )
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then
        #expect(row.rename.derivedName == "feat/tls-pinning")
        #expect(row.rename.derivedNameSource == .branch)

        // and — the sheet is presented against this identity, so a subject that identified as
        // anything but its own worktree could leave a sheet up over a different row.
        #expect(row.rename.id == WorktreeID(rawValue: "w-branch"))
    }

    @Test
    func `given neither a suggestion nor a branch when clearing the alias then only the directory is left`() {
        // given — this is the sheet's "nothing to suggest" case, and the footer is what turns an
        // empty sheet into an explanation.
        let scenario = Scenario(worktrees: [
            Worktree(
                id: WorktreeID(rawValue: "w-directory"),
                projectId: ProjectID(rawValue: "aura"),
                projectName: "aura",
                branch: nil,
                isPrimary: false,
                isDetached: true,
                isLocked: false,
                hasUnbornHead: false,
                alias: nil,
                suggestedAlias: nil,
                displayName: "bridge-cse_01W9sY8PbT2Du1dFGeYGcwWo",
                directoryName: "bridge-cse_01W9sY8PbT2Du1dFGeYGcwWo",
                isPinned: false,
                stats: ChangeStats(filesChanged: 8, insertions: 96, deletions: 204),
                lastModified: aMoment.addingTimeInterval(-5 * 3_600),
                revision: "r1"
            )
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then
        #expect(row.rename == WorktreeRenameSubject(
            worktree: WorktreeID(rawValue: "w-directory"),
            alias: nil,
            suggestedAlias: nil,
            derivedName: "bridge-cse_01W9sY8PbT2Du1dFGeYGcwWo",
            derivedNameSource: .directory
        ))
    }

    // MARK: - What the row will let a reader destroy

    @Test
    func `given an ordinary worktree when its row is built then it offers what the confirmation needs`() {
        // given — the confirmation has to say what is being lost, and the row is where the display
        // name is finally resolved. Resolving it again in the sheet is how the two come to disagree.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "tls-pinning", project: "granita", pinned: false, minutesAgo: 4)
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then
        #expect(row.deletion == .deletable(WorktreeDeletionSubject(
            worktree: WorktreeID(rawValue: "w-tls-pinning"),
            displayName: "tls-pinning",
            stats: .changed(filesChanged: 34, insertions: 1_204, deletions: 318),
            isLocked: false
        )))
    }

    @Test
    func `given a deletion subject when it is identified then it is identified by its worktree`() {
        // given — what a presented dialog is keyed on. Anything else and the confirmation can stay
        // up over a row other than the one it was opened from, which for this control means
        // confirming the deletion of a worktree nobody looked at.
        let subject = WorktreeDeletionSubject(
            worktree: WorktreeID(rawValue: "w-tls-pinning"),
            displayName: "tls-pinning",
            stats: .noChanges,
            isLocked: false
        )

        // given - when - then
        #expect(subject.id == WorktreeID(rawValue: "w-tls-pinning"))
    }

    @Test
    func `given the primary checkout when its row is built then it cannot be deleted`() {
        // given — the primary checkout is in this list and earns a word of its own on the row, so a
        // delete control offered to every row reaches it. It is the repository rather than a
        // checkout of it, and git refuses to remove it at all.
        let scenario = Scenario(worktrees: [
            aClean(named: "main", project: "granita", minutesAgo: 90)
        ])

        // when
        let row = scenario.listing(mode: .mostRecentFirst, showingQuiet: true).sections[0].rows[0]

        // then
        #expect(row.deletion == .primaryCheckout)
    }

    @Test
    func `given a locked worktree when its row is built then it can still be deleted and says so`() {
        // given — **the row this list is nearly all of.** A lock used to refuse the control, on the
        // grounds that a lock is a person on that Mac saying do not remove this. Nobody sets one by
        // hand; Claude Code sets one on every worktree it creates, so the rule refused deletion on
        // essentially every row Granita shows. The flag now travels into the confirmation instead, so
        // the reader is the one overriding the lock and is told they are.
        let scenario = Scenario(worktrees: [locked(named: "held", project: "granita")])

        // when
        let row = scenario.listing(mode: .mostRecentFirst).sections[0].rows[0]

        // then
        #expect(row.deletion == .deletable(WorktreeDeletionSubject(
            worktree: WorktreeID(rawValue: "w-held"),
            displayName: "held",
            stats: .changed(filesChanged: 34, insertions: 1_204, deletions: 318),
            isLocked: true
        )))
    }

    @Test
    func `given a deletable worktree when its refusal is read then there is none`() {
        // given - when - then
        let subject = WorktreeDeletionSubject(
            worktree: WorktreeID(rawValue: "w-tls-pinning"),
            displayName: "tls-pinning",
            stats: .noChanges,
            isLocked: false
        )
        #expect(WorktreeDeletability.deletable(subject).refusal == nil)
    }

    @Test
    func `given the primary checkout when its refusal is read then it names what the row is`() {
        // given - when - then — **the sentence is asserted here because nowhere else can.** It is
        // drawn in a context menu, which the system presents into an overlay no snapshot includes,
        // and it exists to stop a row that will not delete reading as an app that does not work.
        let refusal = WorktreeDeletability.primaryCheckout.refusal
        #expect(refusal?.sentence == "The project’s own checkout can’t be deleted")
        #expect(refusal?.symbol == "house")
    }

    @Test
    func `given a worktree that is both primary and locked when its row is built then it says primary`() {
        // given — the lock no longer refuses anything, so the primary checkout is the only reason
        // left and it is the one that is true of the repository rather than of a setting somebody
        // can undo. Git refuses this one however many times it is forced.
        let scenario = Scenario(worktrees: [primaryAndLocked(named: "main", project: "granita")])

        // when
        let row = scenario.listing(mode: .mostRecentFirst, showingQuiet: true).sections[0].rows[0]

        // then
        #expect(row.deletion == .primaryCheckout)
    }

    @Test
    func `given a worktree with no commits yet when its row is built then the confirmation says so`() {
        // given — an unborn head takes the stats slot, so the confirmation cannot promise a number
        // of files. It carries whatever the row shows, which in this case is that there is nothing
        // to compare against rather than that nothing changed.
        let scenario = Scenario(worktrees: [unborn(named: "day-one", project: "granita")])

        // when
        let row = scenario.listing(mode: .mostRecentFirst, showingQuiet: true).sections[0].rows[0]

        // then
        #expect(row.deletion == .deletable(WorktreeDeletionSubject(
            worktree: WorktreeID(rawValue: "w-day-one"),
            displayName: "day-one",
            stats: .noCommitsYet,
            isLocked: false
        )))
    }

    // MARK: - What the toolbar has to offer

    @Test(arguments: [
        (WorktreeSidebarState.loading, false),
        (.failed(.rateLimited), false),
        (.noProjects, false),
        (.allQuiet(worktreeCount: 3, projectNames: ["granita"]), true),
        (.listing(WorktreeListing(sections: [], quietCount: 0)), true)
    ])
    func `given a state when the toolbar is drawn then the menu is there only if it can do anything`(
        state: WorktreeSidebarState,
        isArrangeable: Bool
    ) {
        // given - when - then — absent rather than disabled: a menu over "no repository is enabled"
        // offers to rearrange nothing, and design §2 draws no control in that frame's bar at all.
        #expect(state.isArrangeable == isArrangeable)
    }

    // MARK: - Nothing to show

    @Test
    func `given no worktrees at all when listing then no project is enabled on the Mac`() {
        // given — a project always has at least its primary checkout, so an empty answer means the
        // Mac is serving nothing rather than that everything is clean.
        let scenario = Scenario(worktrees: [])

        // when
        let state = scenario.state(mode: .groupedByProject)

        // then
        #expect(state == .noProjects)
    }

    @Test
    func `given every worktree clean when hiding them then the state says how many and where`() {
        // given — the count is what makes this state trustworthy rather than alarming, and the
        // project names are what say the Mac is serving something.
        let scenario = Scenario(worktrees: [
            aClean(named: "main", project: "granita", minutesAgo: 4_320),
            aClean(named: "spike", project: "aura", minutesAgo: 60),
            aClean(named: "toolchain", project: "aura", minutesAgo: 90)
        ])

        // when
        let state = scenario.state(mode: .groupedByProject, showingQuiet: false)

        // then
        #expect(state == .allQuiet(worktreeCount: 3, projectNames: ["aura", "granita"]))
    }

    @Test
    func `given every worktree clean when showing them then they are an ordinary listing`() {
        // given — "Show them anyway" has to reach the rows, or it is a button that reports success
        // and leaves the same empty screen up.
        let scenario = Scenario(worktrees: [aClean(named: "main", project: "granita", minutesAgo: 4_320)])

        // when
        let state = scenario.state(mode: .groupedByProject, showingQuiet: true)

        // then
        #expect(state == .listing(scenario.listing(mode: .groupedByProject, showingQuiet: true)))
    }

    // MARK: -

    private struct Scenario {

        private let worktrees: [Worktree]

        init(worktrees: [Worktree]) {
            self.worktrees = worktrees
        }

        func listing(mode: WorktreeListMode, showingQuiet: Bool = false) -> WorktreeListing {
            WorktreeListing(of: worktrees, mode: mode, showingQuiet: showingQuiet, now: aMoment)
        }

        func state(mode: WorktreeListMode, showingQuiet: Bool = false) -> WorktreeSidebarState {
            WorktreeSidebarState(of: worktrees, mode: mode, showingQuiet: showingQuiet, now: aMoment)
        }
    }
}

// MARK: -

/// Fixed rather than `Date()`, because every age in this suite is measured against it and a clock
/// read inside the subject would make each assertion a race with the machine running it.
private let aMoment = Date(timeIntervalSince1970: 1_800_000_000)

private func aWorktree(
    named name: String,
    project: String,
    pinned: Bool,
    minutesAgo: Int
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
        alias: nil,
        suggestedAlias: nil,
        displayName: name,
        directoryName: "d-\(name)",
        isPinned: pinned,
        stats: ChangeStats(filesChanged: 34, insertions: 1_204, deletions: 318),
        lastModified: aMoment.addingTimeInterval(TimeInterval(-minutesAgo * 60)),
        revision: "r1"
    )
}

private func locked(named name: String, project: String) -> Worktree {
    aWorktree(named: name, project: project, pinned: false, minutesAgo: 4).with(isLocked: true)
}

private func primaryAndLocked(named name: String, project: String) -> Worktree {
    aWorktree(named: name, project: project, pinned: false, minutesAgo: 4)
        .with(isPrimary: true, isLocked: true)
}

private func unborn(named name: String, project: String) -> Worktree {
    aWorktree(named: name, project: project, pinned: false, minutesAgo: 4).with(hasUnbornHead: true)
}

private extension Worktree {

    /// One field changed and the rest carried, so a test that is about a flag says only that.
    ///
    /// A domain struct takes no defaults in its memberwise init — the compiler is meant to catch a
    /// field nobody handled — so this is where the twenty unchanged ones get written once.
    func with(
        isPrimary: Bool? = nil,
        isLocked: Bool? = nil,
        hasUnbornHead: Bool? = nil
    ) -> Worktree {
        Worktree(
            id: id,
            projectId: projectId,
            projectName: projectName,
            branch: branch,
            isPrimary: isPrimary ?? self.isPrimary,
            isDetached: isDetached,
            isLocked: isLocked ?? self.isLocked,
            hasUnbornHead: hasUnbornHead ?? self.hasUnbornHead,
            alias: alias,
            suggestedAlias: suggestedAlias,
            displayName: displayName,
            directoryName: directoryName,
            isPinned: isPinned,
            stats: stats,
            lastModified: lastModified,
            revision: revision
        )
    }
}

private func aClean(named name: String, project: String, minutesAgo: Int) -> Worktree {
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
        lastModified: aMoment.addingTimeInterval(TimeInterval(-minutesAgo * 60)),
        revision: "r1"
    )
}
