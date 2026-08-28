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
    func `given a read this phone called off when it ends then the Mac is not blamed for it`() async {
        // given — **this is the screen it happened on.** A `.task` is cancelled the moment its view
        // goes away, so opening a worktree while this list is still loading tears the read down. It
        // came back as *Could not read your Mac* with `NSURLErrorDomain Code=-999 "cancelled"` in
        // the small print, on the screen the reader reached by pressing Back — the app blaming the
        // Mac for something the app did. Seen on a real iPhone.
        let scenario = Scenario(worktrees: [], readFailure: .cancelled)

        // when
        await scenario.sut.load()

        // then — no failure screen, and no invented content either.
        #expect(scenario.sut.state != .failed(.cancelled))
    }

    @Test
    func `given a failed read when the same model retries then the failure leaves the screen`() async {
        // given — **one model through both**, which is the point: `/v1/worktrees` builds a change
        // set for every worktree of every enabled project, measured at over two minutes across ten
        // real repositories, and a retry that left the failure up for that long was reported as a
        // button with nothing behind it.
        let scenario = Scenario(
            worktrees: [aWorktree(named: "diff scroll", project: "granita")],
            refusesTheFirstRead: .unreachable(diagnostic: "NWError -65563")
        )
        await scenario.sut.load()
        #expect(scenario.sut.state == .failed(.unreachable(diagnostic: "NWError -65563")))

        // when — the reader presses Try Again
        await scenario.sut.load()

        // then
        #expect(scenario.sut.state != .failed(.unreachable(diagnostic: "NWError -65563")))
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
        #expect(scenario.sut.writeFailure == .edit(.worktreeGone))
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
        #expect(scenario.sut.writeFailure == .edit(.unauthorized))
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
        #expect(scenario.sut.writeFailure == .edit(.worktreeGone))
        #expect(scenario.rows.map(\.displayName) == ["diff scroll"])
    }

    // MARK: - Deleting

    @Test
    func `given a worktree when deletion is confirmed then the Mac is asked and the row goes`() async throws {
        // given
        let scenario = Scenario(worktrees: [
            aWorktree(named: "diff scroll", project: "granita"),
            aWorktree(named: "session index", project: "granita", minutesAgo: 1)
        ])
        await scenario.sut.load()
        let subject = try #require(scenario.deletionSubject(of: "w-diff scroll"))

        // when
        scenario.sut.beginDeleting(subject)
        await scenario.sut.confirmDeletion(of: subject)

        // then
        #expect(await scenario.repository.deleted == [WorktreeID(rawValue: "w-diff scroll")])
        #expect(scenario.rows.map(\.displayName) == ["session index"])
        #expect(scenario.sut.deleting == nil)
    }

    @Test
    func `given the confirmation is up when it is cancelled then nothing is deleted`() async throws {
        // given — the whole point of the dialog. Asserted on what left the phone rather than on what
        // is left in the list, because not asking and asking-and-being-refused leave the same list.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()
        let subject = try #require(scenario.deletionSubject(of: "w-diff scroll"))

        // when
        scenario.sut.beginDeleting(subject)
        scenario.sut.cancelDeleting()

        // then
        #expect(await scenario.repository.deleted.isEmpty)
        #expect(scenario.sut.deleting == nil)
        #expect(scenario.rows.map(\.displayName) == ["diff scroll"])
    }

    @Test
    func `given the confirmation was dismissed when it is confirmed then what it named is deleted`(
    ) async throws {
        // given — **the regression test for a control that did nothing at all.** The subject used to
        // be read back off the model, and dismissing an alert writes `false` through its
        // `isPresented` binding, which clears it synchronously — while the button's own `Task` body
        // runs a turn later on the main actor. So the guard failed, nothing was deleted, and every
        // baseline stayed green, because a raster does not include an alert and cannot press a
        // button. This sequence is that ordering, made deterministic.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()
        let subject = try #require(scenario.deletionSubject(of: "w-diff scroll"))

        // when
        scenario.sut.beginDeleting(subject)
        scenario.sut.cancelDeleting()
        await scenario.sut.confirmDeletion(of: subject)

        // then — what was confirmed is what was destroyed, whatever the model happened to hold.
        #expect(await scenario.repository.deleted == [WorktreeID(rawValue: "w-diff scroll")])
        #expect(scenario.rows.isEmpty)
    }

    @Test
    func `given a deletion in flight when the rows are read then that one says it is going`() async throws {
        // given — the row is dropped only once the Mac answers, so there is a real window with the
        // request outstanding and the row still on screen. Without a mark on it, that window is a
        // confirmation that appears to have done nothing.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()
        let subject = try #require(scenario.deletionSubject(of: "w-diff scroll"))
        await scenario.repository.holdTheNextDeletion()

        // when
        let deletion = Task { await scenario.sut.confirmDeletion(of: subject) }
        await scenario.repository.waitForADeletionToArrive()

        // then
        #expect(scenario.sut.removing == [WorktreeID(rawValue: "w-diff scroll")])

        // and then — the mark is cleared when the answer lands, on every path.
        await scenario.repository.releaseHeldDeletions()
        await deletion.value
        #expect(scenario.sut.removing.isEmpty)
    }

    @Test
    func `given a deletion in flight when a second is confirmed then both rows say they are going`(
    ) async throws {
        // given — this is why it is a set rather than one identifier. Confirm one, swipe another and
        // confirm that too is reachable at LAN speed, and with an optional the second deletion's
        // answer would clear the first one's mark and put a row back on screen that is still going.
        let scenario = Scenario(worktrees: [
            aWorktree(named: "diff scroll", project: "granita"),
            aWorktree(named: "session index", project: "granita", minutesAgo: 1)
        ])
        await scenario.sut.load()
        let first = try #require(scenario.deletionSubject(of: "w-diff scroll"))
        let second = try #require(scenario.deletionSubject(of: "w-session index"))
        await scenario.repository.holdTheNextDeletion()

        // when
        let deletions = Task {
            async let one: Void = scenario.sut.confirmDeletion(of: first)
            async let two: Void = scenario.sut.confirmDeletion(of: second)
            _ = await (one, two)
        }
        await scenario.repository.waitForADeletionToArrive(count: 2)

        // then
        #expect(scenario.sut.removing == [
            WorktreeID(rawValue: "w-diff scroll"),
            WorktreeID(rawValue: "w-session index")
        ])

        // and then
        await scenario.repository.releaseHeldDeletions()
        await deletions.value
        #expect(scenario.sut.removing.isEmpty)
        #expect(scenario.sut.state == .noProjects)
    }

    @Test
    func `given the Mac refused a deletion when the refusal is read then it says it was a deletion`(
    ) async throws {
        // given — the routing the refusal type exists for. The same `ApiFailure` leaves a rename
        // exactly as it was and leaves a deletion in a state this phone cannot describe, so the
        // screen has to be able to tell which write it was without asking the failure.
        let scenario = Scenario(
            worktrees: [aWorktree(named: "diff scroll", project: "granita")],
            writeFailure: .unreachable(diagnostic: "NWError -65563")
        )
        await scenario.sut.load()
        let subject = try #require(scenario.deletionSubject(of: "w-diff scroll"))

        // when
        await scenario.sut.confirmDeletion(of: subject)

        // then
        #expect(scenario.sut.writeFailure == .deletion(.unreachable(diagnostic: "NWError -65563")))
    }

    @Test
    func `given a confirmation on screen when the prompt is put down then nothing is deleted`() async throws {
        // given — one alert modifier serves the confirmation and the refusal, so dismissing it means
        // two different things and the wrong one silently arms a deletion.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()
        let subject = try #require(scenario.deletionSubject(of: "w-diff scroll"))
        scenario.sut.beginDeleting(subject)

        // when
        scenario.sut.dismissPrompt()

        // then
        #expect(scenario.sut.deleting == nil)
        #expect(await scenario.repository.deleted.isEmpty)
    }

    @Test
    func `given a refusal on screen when the prompt is put down then it is the refusal that goes`() async {
        // given — the other half. Clearing the wrong one leaves a refusal on screen that the reader
        // cannot close, because the binding says it is no longer presented while the model says it is.
        let scenario = Scenario(
            worktrees: [aWorktree(named: "diff scroll", project: "granita")],
            writeFailure: .unauthorized
        )
        await scenario.sut.load()
        await scenario.sut.setPinned(true, on: WorktreeID(rawValue: "w-diff scroll"))

        // when
        scenario.sut.dismissPrompt()

        // then
        #expect(scenario.sut.writeFailure == nil)
    }

    @Test
    func `given the Mac refused a pin when the refusal is read then it says it was an edit`() async {
        // given — the other half of the same routing, so a pin cannot borrow a deletion's sentence.
        let scenario = Scenario(
            worktrees: [aWorktree(named: "diff scroll", project: "granita")],
            writeFailure: .unreachable(diagnostic: "NWError -65563")
        )
        await scenario.sut.load()

        // when
        await scenario.sut.setPinned(true, on: WorktreeID(rawValue: "w-diff scroll"))

        // then
        #expect(scenario.sut.writeFailure == .edit(.unreachable(diagnostic: "NWError -65563")))
    }

    @Test
    func `given the Mac refused a deletion when it is confirmed then the row stays and the reader is told`(
    ) async throws {
        // given — the row is dropped only once the Mac says it is gone. Dropping it optimistically
        // would show a worktree still on that Mac as deleted, which is the one mistake this feature
        // can make that a reader cannot see and cannot undo.
        let scenario = Scenario(
            worktrees: [aWorktree(named: "diff scroll", project: "granita")],
            writeFailure: .worktreeNotDeletable(message: "that worktree is locked")
        )
        await scenario.sut.load()
        let subject = try #require(scenario.deletionSubject(of: "w-diff scroll"))

        // when
        scenario.sut.beginDeleting(subject)
        await scenario.sut.confirmDeletion(of: subject)

        // then
        #expect(scenario.sut.writeFailure == .deletion(.worktreeNotDeletable(message: "that worktree is locked")))
        #expect(scenario.rows.map(\.displayName) == ["diff scroll"])
        #expect(scenario.sut.deleting == nil)
    }

    @Test
    func `given a worktree already gone from the Mac when it is deleted then the row goes anyway`() async throws {
        // given — an agent removes one every day, so a reader can confirm a deletion for a worktree
        // that stopped existing between the read and the tap.
        let scenario = Scenario(
            worktrees: [aWorktree(named: "diff scroll", project: "granita")],
            writeFailure: .worktreeGone
        )
        await scenario.sut.load()
        let subject = try #require(scenario.deletionSubject(of: "w-diff scroll"))

        // when
        scenario.sut.beginDeleting(subject)
        await scenario.sut.confirmDeletion(of: subject)

        // then — the reader asked for it gone and it is gone. Reporting a failure would put a
        // sentence on screen about a difference nobody can see and nobody has to act on.
        #expect(scenario.sut.writeFailure == nil)
        #expect(scenario.rows.isEmpty)
    }

    @Test
    func `given the last worktree of a project when it is deleted then the list says there is nothing`(
    ) async throws {
        // given — deleting the only row empties the list, and an empty listing is a different state
        // rather than a listing with no sections in it.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()
        let subject = try #require(scenario.deletionSubject(of: "w-diff scroll"))

        // when
        scenario.sut.beginDeleting(subject)
        await scenario.sut.confirmDeletion(of: subject)

        // then
        #expect(scenario.sut.state == .noProjects)
    }

    // MARK: - Naming what was chosen

    @Test
    func `given a chosen worktree when its name is asked for then it is the name the row showed`() async {
        // given
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita", alias: "Scroll")])
        await scenario.sut.load()

        // when
        let name = scenario.sut.displayName(of: WorktreeID(rawValue: "w-diff scroll"))

        // then — the resolved display name rather than the branch, because the row showed the alias
        // and a screen titled anything else reads as having opened something different.
        #expect(name == "Scroll")
    }

    @Test
    func `given a worktree that left the list when its name is asked for then a name still comes back`() async {
        // given — read, chosen, and gone from the next read before the screen it opened was drawn.
        let scenario = Scenario(worktrees: [aWorktree(named: "diff scroll", project: "granita")])
        await scenario.sut.load()

        // when
        let name = scenario.sut.displayName(of: WorktreeID(rawValue: "w-vanished"))

        // then — the screen is titled by this, so absence has to be a word rather than nothing.
        #expect(name == "This worktree")
    }

    @Test
    func `given nothing has been read yet when a name is asked for then a name still comes back`() {
        // given — the quiet worktrees are hidden and the list is a refusal, both of which leave the
        // state holding no rows at all while a chosen identifier is still on the stack.
        let scenario = Scenario(worktrees: [], readFailure: .unreachable(diagnostic: "NWError -65563"))

        // when
        let name = scenario.sut.displayName(of: WorktreeID(rawValue: "w-diff scroll"))

        // then
        #expect(name == "This worktree")
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

        /// What the row would hand a confirmation, or nothing when that row refuses to offer one.
        ///
        /// Taken off the row rather than assembled here, because that is the only way the model is
        /// driven in the app — and which rows have one at all is `WorktreeListing`'s question.
        func deletionSubject(of worktree: String) -> WorktreeDeletionSubject? {
            guard case .deletable(let subject)? = rows
                .first(where: { $0.id == WorktreeID(rawValue: worktree) })?
                .deletion
            else { return nil }
            return subject
        }

        init(
            worktrees: [Worktree],
            readFailure: ApiFailure? = nil,
            refusesTheFirstRead: ApiFailure? = nil,
            writeFailure: ApiFailure? = nil,
            preferences: FakeWorktreeListPreferences = FakeWorktreeListPreferences()
        ) {
            repository = FakeGranitaRepository(
                worktrees: worktrees,
                readFailure: readFailure,
                writeFailure: writeFailure,
                refusesTheFirstRead: refusesTheFirstRead
            )
            self.preferences = preferences
            sut = ClientWorktreesModel(
                macName: "Mac Studio",
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
